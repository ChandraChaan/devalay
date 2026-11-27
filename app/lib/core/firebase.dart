import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api.dart';
import 'languages.dart';
import 'notifications.dart';
import 'storage.dart';
import 'usage.dart';

/// Crash reports, push announcements, force update and usage analytics (daily users, screen
/// views), all through the Devalay Firebase project. Firebase is optional: a build without google-services.json
/// (forks, tests) skips all of it and the app works as before.
class FirebaseServices {
  static bool enabled = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      enabled = true;
    } catch (e) {
      debugPrint('Firebase not configured: $e');
      return;
    }
    if (!Usage.sharing) {
      unawaited(FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false).catchError((Object _) {}));
    }
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    // Uncaught async errors land here. The app keeps running (we return true), so only real bugs
    // are recorded as fatal. A lost connection is expected on Indian mobile data: Riverpod 3 reports
    // a data provider that failed offline here even though its screen already shows "Try again",
    // and counting those as crashes hid the real ones.
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: !isNetworkFailure(error));
      return true;
    };
    // Notification messages arrive in the system tray by themselves while the app is in
    // the background; in the foreground Android shows nothing, so mirror them locally.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null) Notifications.announce(n.title ?? 'Devalay', n.body ?? '');
    });
  }

  static const _topicsKey = 'fcm_topics';

  static String? _lastScreen;

  /// One screen_view per screen the user lands on, named by its route pattern ('home',
  /// 'books/slug'), never by the item's id or the user's input. Firebase's automatic
  /// first_open, session_start and user_engagement events give daily new and active users.
  static void logScreen(String routePattern) {
    if (!enabled) return;
    final name = routePattern.replaceFirst(RegExp('^/'), '').replaceAll(':', '');
    final screen = name.isEmpty ? 'root' : name;
    if (screen == _lastScreen) return;
    _lastScreen = screen;
    Usage.screen(screen);
    unawaited(
      FirebaseAnalytics.instance
          .logScreenView(screenName: screen, screenClass: screen)
          .catchError((Object e) => debugPrint('screen_view not logged: $e')),
    );
  }

  /// Topics let the Firebase console target everyone, or one language's users. The twelve topic
  /// calls go out when the language changes and once a week after that, not on every launch.
  static Future<void> subscribe(String language, {bool force = true}) async {
    if (!enabled) return;
    final done = Boxes.stats.get(_topicsKey);
    final today = DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    if (!force && done is Map && done['lang'] == language && today - ((done['day'] as num?) ?? 0) < 7) return;
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.subscribeToTopic('all');
      for (final lang in appLanguages.map((l) => l.code)) {
        if (lang == language) {
          await messaging.subscribeToTopic('lang_$lang');
        } else {
          await messaging.unsubscribeFromTopic('lang_$lang');
        }
      }
      await Boxes.stats.put(_topicsKey, {'lang': language, 'day': today});
    } catch (e) {
      debugPrint('FCM topic subscription failed: $e'); // offline; retried on next launch
    }
  }
}

class UpdateInfo {
  const UpdateInfo({required this.required, required this.url, required this.message, this.build = 0, this.latest = 0});
  final bool required;

  /// This build's version code and the newest one published (Remote Config `latest_version_code`).
  final int build, latest;
  final String url;
  final Map<String, String> message;
}

const _playUrl = 'https://play.google.com/store/apps/details?id=com.chandrachaan.devalay';
const _apkUrl = 'https://github.com/ChandraChaan/devalay/releases/latest/download/devalay.apk';

/// Remote Config `min_version_code`: builds below it must update before use.
final updateProvider = FutureProvider<UpdateInfo>((ref) async {
  const none = UpdateInfo(required: false, url: '', message: {});
  if (!FirebaseServices.enabled) return none;
  final rc = FirebaseRemoteConfig.instance;
  try {
    await rc.setConfigSettings(
      RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 1)),
    );
    await rc.setDefaults(const {
      'min_version_code': 0,
      'latest_version_code': 0,
      'update_message_te': '',
      'update_message_hi': '',
      'update_message_en': '',
    });
    await rc.fetchAndActivate();
  } catch (_) {
    // Offline: the last activated values (or defaults) still apply.
  }
  final info = await PackageInfo.fromPlatform();
  // Compare by version name: per-ABI APKs add 1000/2000/4000 to the build number, so it would
  // overstate the version. 1.2.3 -> 10203, matching release.yml and min_version_code.
  final build = versionCodeOf(info.version);
  final fromPlay = info.installerStore == 'com.android.vending';
  return UpdateInfo(
    required: build < rc.getInt('min_version_code'),
    build: build,
    latest: rc.getInt('latest_version_code'),
    url: fromPlay ? _playUrl : _apkUrl,
    message: {for (final l in appLanguages) l.code: rc.getString('update_message_${l.code}')},
  );
});

int versionCodeOf(String version) {
  final p = version.split('+').first.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  while (p.length < 3) {
    p.add(0);
  }
  return p[0] * 10000 + p[1] * 100 + p[2];
}

/// Whether [error] is a failed or interrupted network request (offline, timeout, connection reset),
/// as opposed to a bug.
bool isNetworkFailure(Object error) => switch (error) {
  ApiException(isOffline: true) => true,
  SocketException() || HttpException() || HandshakeException() || TimeoutException() => true,
  DioException(:final type) =>
    type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout,
  _ => false,
};
