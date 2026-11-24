import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'firebase.dart';
import 'location.dart';
import 'storage.dart';

/// The Realtime Database that holds live presence. Set explicitly so builds whose
/// google-services.json predates the database (CI) still find it.
const rtdbUrl = 'https://devalay-chandra-default-rtdb.asia-southeast1.firebasedatabase.app';

/// Usage statistics for the owner's admin screen, modelled on chandrachaan.com's visitor telemetry.
///
/// Each install signs in anonymously (no account, no name, no email) and reports:
///  * live presence in the Realtime Database `status/{uid}`: online or offline, the current screen
///    (route pattern, never an item the user typed), language, app version and state;
///  * a summary in Firestore `installs/{uid}`: first and last seen, sessions, a count per feature;
///  * the actions themselves in Firestore `events`, a batch per write (at most one a minute, ten
///    seconds after the app opens), each action a fixed name plus an optional short id.
///
/// Only the app's own screens and actions are recorded: no typed text, contacts, birth details or
/// precise location (the state comes from the city the user picked for Panchang). Settings →
/// "Share usage statistics" turns all of it off, and "Delete my usage data" removes what was sent.
class Usage {
  Usage._();

  static const _prefKey = 'usage_sharing';
  static const _firstKey = 'usage_first_uid';
  static const _maxBatch = 60;
  static const _sessionGap = Duration(minutes: 30);
  static DateTime? _pausedAt;

  static bool get sharing => Boxes.prefs.get(_prefKey, defaultValue: true) as bool;

  /// Follows the Settings switch, for widgets that show it.
  static final sharingChanges = ValueNotifier<bool>(sharing);

  static Future<void> _setPref(bool on) async {
    await Boxes.prefs.put(_prefKey, on);
    sharingChanges.value = on;
  }

  static bool _started = false;
  static bool _online = false;
  static String? _uid;
  static String _screen = 'root';
  static String _version = '';
  static int _build = 0;
  static String _installer = '';
  static final _pending = <Map<String, Object?>>[];
  static final _counts = <String, int>{};
  static bool _newSession = true;
  static Timer? _timer;
  static DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
  static AppLifecycleListener? _lifecycle;
  static StreamSubscription<User?>? _authSub;
  static final String _sessionId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  /// The anonymous id this install reports under, once signed in.
  static String? get uid => _uid;

  /// The presence database; the admin screen listens to it too.
  static FirebaseDatabase get rtdb =>
      FirebaseDatabase.instanceFor(app: FirebaseAuth.instance.app, databaseURL: rtdbUrl);

  static Future<void> init() async {
    if (!FirebaseServices.enabled || _started) return;
    _started = true;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _build = versionCodeOf(info.version);
      _installer = info.installerStore ?? '';
    } catch (_) {}
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
        if (away > _sessionGap && _uid != null) {
          _newSession = true;
          record('app_open');
        }
        unawaited(_goActive());
      },
      onPause: () {
        _pausedAt = DateTime.now();
        unawaited(_goAway());
      },
      onDetach: () => unawaited(_goAway()),
    );
    // An admin signing in with Google replaces the anonymous user; stop reporting until they sign
    // out again, so the owner's own use never mixes with the users'.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _uid = null;
        if (sharing) unawaited(_signIn());
      } else if (user.isAnonymous) {
        final changed = _uid != user.uid;
        _uid = user.uid;
        if (changed && sharing) {
          _newSession = true;
          record('app_open');
          unawaited(_goActive());
        }
      } else {
        _uid = null;
        unawaited(_disconnect());
      }
      // The listener's first event (null on a fresh install) starts the anonymous sign-in.
    });
  }

  static Future<void> _signIn() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Usage: anonymous sign-in failed: $e'); // offline; retried on next launch
    }
  }

  /// Called for every screen the user lands on, with the same name Analytics gets.
  static void screen(String name) {
    _screen = name;
    _count(name.replaceAll('/', '_'));
    _add({'k': 'screen', 'n': name});
    if (_online) unawaited(_presence());
  }

  /// A deliberate action: [action] is a fixed snake_case name, [item] an optional short id (a
  /// chapter number, a track id), never text the user typed.
  static void record(String action, {String? item}) {
    if (!FirebaseServices.enabled || !sharing) return;
    _count(action);
    _add({'k': action, if (item != null && item.isNotEmpty) 'n': item.length > 40 ? item.substring(0, 40) : item});
    if (action != 'app_open' && action != 'screen') {
      unawaited(
        FirebaseAnalytics.instance
            .logEvent(name: action, parameters: {'item': ?item})
            .catchError((Object e) => debugPrint('analytics event not logged: $e')),
      );
    }
  }

  static void _count(String key) {
    if (!sharing) return;
    final k = key.length > 40 ? key.substring(0, 40) : key;
    _counts[k] = (_counts[k] ?? 0) + 1;
  }

  static void _add(Map<String, Object?> e) {
    if (!FirebaseServices.enabled || !sharing) return;
    if (_pending.length >= _maxBatch) _pending.removeAt(0);
    _pending.add({...e, 't': DateTime.now().millisecondsSinceEpoch});
    _schedule(important: e['k'] == 'app_open');
  }

  static void _schedule({bool important = false}) {
    if (_timer?.isActive ?? false) {
      if (!important) return;
      _timer!.cancel();
    }
    final sinceLast = DateTime.now().difference(_lastFlush);
    final wait = important ? const Duration(seconds: 10) : const Duration(seconds: 60) - sinceLast;
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () => unawaited(flush()));
  }

  /// Writes pending actions and counters in one batch.
  static Future<void> flush() async {
    _timer?.cancel();
    final uid = _uid;
    if (uid == null || !sharing || (_pending.isEmpty && _counts.isEmpty)) return;
    final items = List<Map<String, Object?>>.of(_pending);
    final counts = Map<String, int>.of(_counts);
    final newSession = _newSession;
    _pending.clear();
    _counts.clear();
    _newSession = false;
    _lastFlush = DateTime.now();
    final db = FirebaseFirestore.instance;
    final install = db.collection('installs').doc(uid);
    final batch = db.batch();
    final first = Boxes.prefs.get(_firstKey) != uid;
    batch.set(install, {
      if (first) 'firstSeen': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'lang': Prefs.load(Boxes.prefs).language,
      'v': _version,
      'build': _build,
      'state': _state(),
      'src': _installer,
      if (newSession) 'sessions': FieldValue.increment(1),
      'f': {for (final e in counts.entries) e.key: FieldValue.increment(e.value)},
    }, SetOptions(merge: true));
    if (items.isNotEmpty) {
      batch.set(db.collection('events').doc(), {
        'uid': uid,
        'at': FieldValue.serverTimestamp(),
        'sid': _sessionId,
        'items': items,
      });
    }
    try {
      await batch.commit();
      if (first) await Boxes.prefs.put(_firstKey, uid);
    } catch (e) {
      // Rules refuse a second firstSeen; the doc already has one.
      if (first && e is FirebaseException && e.code == 'permission-denied') await Boxes.prefs.put(_firstKey, uid);
      debugPrint('Usage: flush failed, keeping for later: $e');
      _pending.insertAll(0, items.take(_maxBatch - _pending.length));
      counts.forEach((k, v) => _counts[k] = (_counts[k] ?? 0) + v);
      _newSession = _newSession || newSession;
    }
  }

  static String _state() {
    final id = Prefs.load(Boxes.prefs).cityId;
    final city = cities.where((c) => c.id == id).firstOrNull;
    return city?.state ?? '';
  }

  static DatabaseReference? get _status => _uid == null ? null : rtdb.ref('status/$_uid');

  static Future<void> _presence() async {
    final ref = _status;
    if (ref == null) return;
    try {
      await ref.set({
        's': 'active',
        't': ServerValue.timestamp,
        'scr': _screen.length > 40 ? _screen.substring(0, 40) : _screen,
        'lang': Prefs.load(Boxes.prefs).language,
        'v': _version,
        'st': _state(),
      });
    } catch (e) {
      debugPrint('Usage: presence not written: $e');
    }
  }

  static Future<void> _goActive() async {
    final ref = _status;
    if (ref == null || !sharing) return;
    try {
      rtdb.goOnline();
      await ref.onDisconnect().update({'s': 'offline', 't': ServerValue.timestamp});
      _online = true;
      await _presence();
    } catch (e) {
      debugPrint('Usage: presence unavailable: $e');
    }
  }

  /// Leaving the app: write what is pending and drop the live connection (the free plan allows
  /// 100 at once, so only open apps hold one). The server's onDisconnect marks the user offline.
  static Future<void> _goAway() async {
    await flush();
    await _disconnect();
  }

  static Future<void> _disconnect() async {
    if (!_online) return;
    _online = false;
    try {
      await _status?.update({'s': 'offline', 't': ServerValue.timestamp});
    } catch (_) {}
    try {
      rtdb.goOffline();
    } catch (_) {}
  }

  /// Settings switch. Turning it off stops all reporting at once.
  static Future<void> setSharing(bool on) async {
    await _setPref(on);
    if (!FirebaseServices.enabled) return;
    unawaited(FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(on).catchError((Object _) {}));
    if (on) {
      if (FirebaseAuth.instance.currentUser == null) {
        await _signIn();
      } else {
        _newSession = true;
        record('app_open');
        await _goActive();
      }
    } else {
      _pending.clear();
      _counts.clear();
      _timer?.cancel();
      await _disconnect();
    }
  }

  /// Turns sharing off, then removes this install's presence, summary and actions and forgets
  /// the anonymous id so nothing new links to what was deleted.
  static Future<void> deleteMyData() async {
    await _setPref(false);
    unawaited(FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false).catchError((Object _) {}));
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return;
    _pending.clear();
    _counts.clear();
    _timer?.cancel();
    await _disconnect();
    final uid = user.uid;
    final db = FirebaseFirestore.instance;
    try {
      rtdb.goOnline();
      await rtdb.ref('status/$uid').remove().timeout(const Duration(seconds: 15));
    } catch (_) {
    } finally {
      rtdb.goOffline();
    }
    while (true) {
      final page = await db.collection('events').where('uid', isEqualTo: uid).limit(200).get();
      if (page.docs.isEmpty) break;
      final batch = db.batch();
      for (final d in page.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await db.collection('installs').doc(uid).delete();
    try {
      await user.delete();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @visibleForTesting
  static void reset() {
    _lifecycle?.dispose();
    _authSub?.cancel();
    _started = false;
  }
}
