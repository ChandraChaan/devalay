import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'notifications.dart';
import 'storage.dart';

/// Temple booking catalogue: which services each temple offers online and the official site that
/// books them. Devalay never takes a booking or a payment itself; it explains the service and
/// opens the temple's own portal.
///
/// The catalogue ships in the app (assets/data/temples.json) and the same file is published with
/// the static API, so a changed web address or release date reaches users without an app update.

/// Text in the UI language, falling back to English. Catalogue text is `{en, hi, te}`.
String loc(Object? text, String lang) => text is Map ? '${text[lang] ?? text['en'] ?? ''}' : '${text ?? ''}';

/// India time as wall-clock fields. Temples publish release times in IST wherever the phone is.
DateTime istNow() => DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

/// The usual monthly moment a quota opens: [day] of the month at [hour]:[minute] IST, for visits
/// [ahead] months later. Temples confirm the exact date each month, so the UI calls it "usual".
class ReleaseSlot {
  const ReleaseSlot({required this.day, required this.hour, required this.minute, required this.ahead});

  static ReleaseSlot? parse(Object? json) {
    if (json is! Map) return null;
    final day = json['day'], hour = json['hour'];
    // Day 2 to 28 exists in every month and leaves room for the reminder on the evening before.
    if (day is! int || hour is! int || day < 2 || day > 28 || hour < 0 || hour > 23) return null;
    final minute = json['minute'] is int ? json['minute'] as int : 0;
    final ahead = json['ahead'] is int ? json['ahead'] as int : 0;
    return ReleaseSlot(day: day, hour: hour, minute: minute.clamp(0, 59), ahead: ahead.clamp(0, 12));
  }

  final int day, hour, minute, ahead;

  /// The next opening after [now]; both are IST wall-clock times.
  DateTime next(DateTime now) {
    final thisMonth = DateTime.utc(now.year, now.month, day, hour, minute);
    return thisMonth.isAfter(now) ? thisMonth : DateTime.utc(now.year, now.month + 1, day, hour, minute);
  }

  /// First day of the month whose quota opens at [opening].
  DateTime quotaMonth(DateTime opening) => DateTime.utc(opening.year, opening.month + ahead);
}

class TempleService {
  TempleService(this._j) : release = ReleaseSlot.parse(_j['release']);
  final Map _j;
  final ReleaseSlot? release;

  String get id => '${_j['id']}';

  /// One of [serviceCategories]; anything else is shown under "more".
  String get category => serviceCategories.contains(_j['cat']) ? '${_j['cat']}' : 'more';
  String get emoji => '${_j['emoji'] ?? '🛕'}';
  String name(String lang) => loc(_j['name'], lang);
  String summary(String lang) => loc(_j['summary'], lang);
  String price(String lang) => loc(_j['price'], lang);
  String who(String lang) => loc(_j['who'], lang);
  List<String> notes(String lang) => [for (final n in _j['notes'] as List? ?? const []) loc(n, lang)];

  /// A service that is booked on a different official site than the temple's main portal.
  String? get url => _j['url'] as String?;
}

const serviceCategories = ['darshan', 'seva', 'stay', 'donate', 'more'];

class TempleLink {
  TempleLink(this._j);
  final Map _j;
  String label(String lang) => loc(_j['label'], lang);
  String get url => '${_j['url']}';
}

class Temple {
  Temple(this._j)
    : services = [for (final s in _j['services'] as List? ?? const []) TempleService(s as Map)],
      links = [for (final l in _j['links'] as List? ?? const []) TempleLink(l as Map)];
  final Map _j;
  final List<TempleService> services;
  final List<TempleLink> links;

  String get id => '${_j['id']}';
  bool get featured => _j['featured'] == true;
  String get emoji => '${_j['emoji'] ?? '🛕'}';
  List<String> get colors => [for (final c in _j['colors'] as List? ?? const []) '$c'];
  String name(String lang) => loc(_j['name'], lang);
  String short(String lang) => _j['short'] == null ? name(lang) : loc(_j['short'], lang);
  String deity(String lang) => loc(_j['deity'], lang);
  String place(String lang) => loc(_j['place'], lang);
  String get state => '${_j['state'] ?? ''}';
  String tagline(String lang) => loc(_j['tagline'], lang);
  String login(String lang) => loc(_j['login'], lang);
  String get portalUrl => '${(_j['portal'] as Map)['url']}';
  String get portalHost => '${(_j['portal'] as Map)['host'] ?? Uri.parse(portalUrl).host}';
  List<String> steps(String lang) => [for (final s in _j['steps'] as List? ?? const []) loc(s, lang)];
  List<String> tips(String lang) => [for (final s in _j['tips'] as List? ?? const []) loc(s, lang)];

  /// Ways to have darshan without booking online: `(name, summary)`.
  List<(String, String)> walkIn(String lang) => [
    for (final w in _j['walkin'] as List? ?? const []) (loc((w as Map)['name'], lang), loc(w['summary'], lang)),
  ];

  String urlFor(TempleService service) => service.url ?? portalUrl;

  /// Where the static API publishes this temple's own announcements, if it has a feed.
  String? get updatesPath {
    final path = _j['updates'];
    return path is String && path.startsWith('/temples/') ? path : null;
  }

  /// Services with a usual release slot, in the order they open during the month.
  List<TempleService> get releases => services.where((s) => s.release != null).toList()
    ..sort((a, b) {
      final (x, y) = (a.release!, b.release!);
      return (x.day * 1440 + x.hour * 60 + x.minute).compareTo(y.day * 1440 + y.hour * 60 + y.minute);
    });

  /// Matches a search box query against the names in every language, the place and the state.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final text = [
      for (final key in ['name', 'short', 'deity', 'place'])
        if (_j[key] is Map) ...(_j[key] as Map).values,
      state,
    ].join(' ').toLowerCase();
    return text.contains(q);
  }
}

class TempleCatalog {
  TempleCatalog(Map json)
    : schema = json['schema'] is int ? json['schema'] as int : 0,
      version = json['version'] is int ? json['version'] as int : 0,
      updated = DateTime.tryParse('${json['updated']}'),
      temples = [for (final t in json['temples'] as List) Temple(t as Map)];

  /// The catalogue layout this app understands. A published catalogue with another schema is ignored.
  static const supportedSchema = 1;

  final int schema, version;
  final DateTime? updated;
  final List<Temple> temples;

  Temple? byId(String id) => temples.where((t) => t.id == id).firstOrNull;
  List<String> get states => {for (final t in temples) t.state}.toList()..sort();
}

/// Official booking sites only ever open over HTTPS, whatever a catalogue says.
bool isSafeBookingUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == 'https' && uri.host.contains('.');
}

Future<TempleCatalog> loadBundledTemples() async =>
    TempleCatalog(jsonDecode(await rootBundle.loadString('assets/data/temples.json')) as Map);

/// The bundled catalogue at once, then the published one if it is newer.
final templeCatalogProvider = StreamProvider<TempleCatalog>((ref) async* {
  final bundled = await loadBundledTemples();
  yield bundled;
  try {
    final remote = TempleCatalog(await ref.read(apiProvider).get('/temples') as Map);
    if (remote.schema == TempleCatalog.supportedSchema && remote.version > bundled.version) yield remote;
  } catch (_) {
    // Offline, or a server without the catalogue: the bundled copy stays.
  }
});

/// One announcement from a temple's official site, in the temple's own words.
class TempleUpdate {
  TempleUpdate(Map json)
    : title = '${json['title'] ?? ''}'.trim(),
      text = '${json['text'] ?? ''}'.trim(),
      url = json['url'] is String && isSafeBookingUrl(json['url'] as String) ? json['url'] as String : null;

  /// The service it is about ("Accommodation"); may be empty.
  final String title, text;

  /// An official page the announcement links to, if any.
  final String? url;
}

/// A temple's announcements as republished once a day by the static export
/// (backend/app/services/temple_updates.py).
class TempleUpdates {
  TempleUpdates({required this.fetched, required this.items});

  static TempleUpdates? parse(Object? json) {
    if (json is! Map || json['items'] is! List) return null;
    final fetched = DateTime.tryParse('${json['fetched']}');
    if (fetched == null) return null;
    final items = [
      for (final i in json['items'] as List)
        if (i is Map) TempleUpdate(i),
    ].where((u) => u.text.isNotEmpty).toList();
    return TempleUpdates(fetched: fetched, items: items);
  }

  /// When the export last read the temple's site.
  final DateTime fetched;
  final List<TempleUpdate> items;

  /// Old announcements mislead, so a copy that has not been refreshed for a week is not shown.
  bool isFresh(DateTime now) => now.difference(fetched) < const Duration(days: 7);
}

/// The announcements at [path], or null when there are none worth showing (offline, a server
/// without the feed, or a stale copy).
final templeUpdatesProvider = FutureProvider.family<TempleUpdates?, String>((ref, path) async {
  try {
    final updates = TempleUpdates.parse(await ref.read(apiProvider).get(path));
    return updates != null && updates.items.isNotEmpty && updates.isFresh(DateTime.now()) ? updates : null;
  } catch (_) {
    return null;
  }
});

/// Services the user asked to be reminded about, as `templeId/serviceId`.
class TempleReminders extends Notifier<Set<String>> {
  static const _key = 'temple_reminders';

  @override
  Set<String> build() => {...(Boxes.prefs.get(_key, defaultValue: const <String>[]) as List).cast<String>()};

  static String keyFor(Temple temple, TempleService service) => '${temple.id}/${service.id}';

  /// Turns the monthly reminder for [service] on or off. Returns false when the user refused
  /// notifications, so nothing was scheduled.
  Future<bool> set(Temple temple, TempleService service, bool on, {required String lang}) async {
    final key = keyFor(temple, service);
    final slot = service.release;
    if (on && slot != null) {
      if (!await Notifications.requestPermission()) return false;
      await Notifications.scheduleQuota(
        key,
        day: slot.day,
        hour: slot.hour,
        minute: slot.minute,
        temple: temple.short(lang),
        service: service.name(lang),
        lang: lang,
      );
    } else {
      await Notifications.cancelQuota(key);
    }
    state = on ? {...state, key} : ({...state}..remove(key));
    await Boxes.prefs.put(_key, state.toList());
    return true;
  }
}

final templeRemindersProvider = NotifierProvider<TempleReminders, Set<String>>(TempleReminders.new);
