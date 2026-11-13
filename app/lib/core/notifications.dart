import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'i18n.dart';
import 'models.dart';
import 'names.dart';
import 'storage.dart';
import 'telugu.dart';

/// On-device reminders: daily prayer and festival reminders are scheduled with the
/// Android alarm manager and work offline. Push announcements from the Firebase
/// console arrive through [FirebaseServices] and are shown here in the foreground.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _dailyId = 1;
  static const _festivalBase = 1000;

  static const _daily = AndroidNotificationDetails(
    'daily',
    'Daily prayer reminder',
    channelDescription: 'A gentle reminder for your daily prayer',
    importance: Importance.defaultImportance,
  );
  static const _announcement = AndroidNotificationDetails(
    'announcements',
    'Announcements',
    channelDescription: 'Festival greetings and news from Devalay',
    importance: Importance.high,
  );
  static const _festival = AndroidNotificationDetails(
    'festivals',
    'Festival reminders',
    channelDescription: 'Reminders on festival mornings',
    importance: Importance.high,
  );

  static const _panchang = AndroidNotificationDetails(
    'panchang_daily',
    "Today's Panchang",
    channelDescription: "Each morning: today's tithi, nakshatra, Rahu Kalam and festivals",
    importance: Importance.defaultImportance,
  );

  static const _events = AndroidNotificationDetails(
    'my_events',
    'My events',
    channelDescription: 'Birthdays, anniversaries and remembrance days you added to the calendar',
    importance: Importance.high,
  );

  /// The channel's details with the whole body shown when the notification is expanded.
  static NotificationDetails _expanded(AndroidNotificationDetails c, String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      c.channelId,
      c.channelName,
      channelDescription: c.channelDescription,
      importance: c.importance,
      styleInformation: BigTextStyleInformation(body),
    ),
  );

  // One id per calendar day (days since 1970, mod 1000), so a day keeps its id as the window moves.
  static const _panchangBase = 410000;
  static const _legacyPanchangBase = 400000; // 1.3 and earlier: 400000 + position in the window
  static const panchangDays = 45;

  static const _quota = AndroidNotificationDetails(
    'temple_booking',
    'Temple booking reminders',
    channelDescription: 'Reminders before a temple usually opens its online booking',
    importance: Importance.high,
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification')),
    );
  }

  static Future<void> announce(String title, String body) => _plugin.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000 + 2000,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(android: _announcement),
  );

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static tz.TZDateTime _next(int hour, int minute, [DateTime? on]) {
    final now = tz.TZDateTime.now(tz.local);
    if (on != null) return tz.TZDateTime(tz.local, on.year, on.month, on.day, hour, minute);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// One reminder per weekday at the chosen time, naming that day's deity
  /// ("Monday: Shiva's songs"); Telugu homes keep Saturday for Venkateswara.
  static Future<void> scheduleDaily(int hour, int minute, {required String lang}) async {
    await cancelDaily();
    final now = tz.TZDateTime.now(tz.local);
    for (var wd = 0; wd < 7; wd++) {
      var when = _next(hour, minute);
      while (when.weekday - 1 != wd) {
        when = when.add(const Duration(days: 1));
      }
      if (!when.isAfter(now)) when = when.add(const Duration(days: 7));
      final (title, body) = _weekdayMessage(wd, lang);
      await _plugin.zonedSchedule(
        id: _dailyId + wd,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(android: _daily),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static (String, String) _weekdayMessage(int wd, String lang) {
    switch (lang) {
      case 'te':
        const deity = [
          'శివుని',
          'ఆంజనేయ స్వామి',
          'వినాయకుని',
          'శ్రీ మహావిష్ణువు',
          'లక్ష్మీదేవి',
          'శ్రీ వేంకటేశ్వర స్వామి',
          'సూర్యభగవానుని',
        ];
        return (
          '🪔 ${teluguWeekdays[wd]} · ${deity[wd]} పాటలు',
          'ఈ రోజు ${deity[wd]} భక్తి పాటలు వినండి, దీపం వెలిగించండి. నేటి పంచాంగం కూడా చూడండి.',
        );
      case 'hi':
        const day = ['सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार'];
        const deity = ['शिव जी', 'हनुमान जी', 'गणेश जी', 'विष्णु जी', 'माँ लक्ष्मी', 'शनि देव', 'सूर्य देव'];
        return (
          '🪔 ${day[wd]} · ${deity[wd]} के भजन',
          'आज ${deity[wd]} के भजन सुनें, दीप जलाएँ और आज का पंचांग देखें।',
        );
      case 'en':
        const day = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        const deity = ['Shiva', 'Hanuman', 'Ganesha', 'Vishnu', 'Lakshmi', 'Shani Dev', 'Surya'];
        return (
          "🪔 ${day[wd]} · ${deity[wd]}'s songs",
          "Listen to ${deity[wd]}'s bhajans, light a diya and see today's Panchang.",
        );
      default:
        const deity = ['Shiva', 'Hanuman', 'Ganesha', 'Vishnu', 'Lakshmi', 'Shani', 'Surya'];
        final day = fmtDate(lang, 'EEEE', DateTime(2026, 11, 16 + wd)); // 16 Nov 2026 is a Monday
        final name = nameIn(lang, deity[wd]);
        return (
          '🪔 $day · ${t3(lang, 'Bhajans of $name', '$name के भजन', '$name పాటలు')}',
          t3(
            lang,
            'Listen to the bhajans of $name, light a diya and see today\'s Panchang.',
            'आज $name के भजन सुनें, दीप जलाएँ और आज का पंचांग देखें।',
            'ఈ రోజు $name భక్తి పాటలు వినండి, దీపం వెలిగించండి.',
          ),
        );
    }
  }

  static Future<void> cancelDaily() async {
    for (var wd = 0; wd < 7; wd++) {
      await _plugin.cancel(id: _dailyId + wd);
    }
  }

  static Future<void> scheduleFestivals(List<Festival> festivals, {required String lang}) async {
    await cancelFestivals();
    final now = DateTime.now();
    final upcoming = festivals.where((f) => f.major && f.date.isAfter(now.subtract(const Duration(days: 1)))).take(30);
    var i = 0;
    for (final f in upcoming) {
      final when = _next(7, 0, f.date);
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;
      await _plugin.zonedSchedule(
        id: _festivalBase + i++,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(android: _festival),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '🙏 ${f.label(lang)}',
        body: f.description.isNotEmpty && lang == 'en'
            ? f.description
            : t3(lang, 'Wishing you a blessed festival!', 'आज का पर्व मंगलमय हो!', 'పండుగ శుభాకాంక్షలు!'),
      );
    }
  }

  static Future<void> cancelFestivals() async {
    for (var i = 0; i < 30; i++) {
      await _plugin.cancel(id: _festivalBase + i);
    }
  }

  /// One morning message per day for the coming days ([panchangDays] at most). Each day's
  /// text differs, so these are one-off alarms; only days whose time or text changed are sent again.
  static Future<void> schedulePanchang(
    List<({DateTime day, String title, String body})> items, {
    required int hour,
    required int minute,
  }) async {
    final ledger = _Ledger('notif_panchang');
    if (!ledger.exists) await _cancelLegacyPanchang();
    final now = tz.TZDateTime.now(tz.local);
    final wanted = <int>{};
    for (final item in items.take(panchangDays)) {
      final when = _next(hour, minute, item.day);
      if (!when.isAfter(now)) continue;
      final id = _panchangBase + _dayNumber(item.day) % 1000;
      wanted.add(id);
      if (!ledger.changed(id, when, '${item.title}|${item.body}')) continue;
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: when,
        notificationDetails: _expanded(_panchang, item.body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: item.title,
        body: item.body,
      );
    }
    for (final id in ledger.futureIdsExcept(wanted, now)) {
      await _plugin.cancel(id: id);
    }
    await ledger.save(keep: wanted);
  }

  static Future<void> cancelPanchang() async {
    final ledger = _Ledger('notif_panchang');
    if (!ledger.exists) await _cancelLegacyPanchang();
    for (final id in ledger.futureIdsExcept(const {}, tz.TZDateTime.now(tz.local))) {
      await _plugin.cancel(id: id);
    }
    await ledger.save(keep: const {});
  }

  static Future<void> _cancelLegacyPanchang() async {
    for (var i = 0; i < panchangDays; i++) {
      await _plugin.cancel(id: _legacyPanchangBase + i);
    }
  }

  static int _dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// A personal event: the evening before (7 PM) and the morning of (7 AM). Unchanged reminders are
  /// left alone.
  static Future<void> scheduleEvent(
    String id, {
    required DateTime on,
    required (String, String) eve,
    required (String, String) morning,
  }) async {
    final ledger = _Ledger('notif_events');
    final now = tz.TZDateTime.now(tz.local);
    final slots = [(_next(19, 0, on.subtract(const Duration(days: 1))), eve), (_next(7, 0, on), morning)];
    final wanted = <int>{};
    for (final (i, (at, (title, body))) in slots.indexed) {
      if (!at.isAfter(now)) continue;
      final nid = _eventId(id) + i;
      wanted.add(nid);
      if (!ledger.changed(nid, at, '$title|$body')) continue;
      await _plugin.zonedSchedule(
        id: nid,
        scheduledDate: at,
        notificationDetails: _expanded(_events, body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    }
    final mine = {_eventId(id), _eventId(id) + 1};
    for (final nid in ledger.futureIdsExcept(wanted, now).where(mine.contains)) {
      await _plugin.cancel(id: nid);
    }
    await ledger.save(keep: wanted, within: mine);
  }

  static Future<void> cancelEvent(String id) async {
    final ledger = _Ledger('notif_events');
    final mine = {_eventId(id), _eventId(id) + 1};
    // Before 1.4 nothing was recorded, so cancel both slots once; after that only what is pending.
    final pending = ledger.exists
        ? ledger.futureIdsExcept(const {}, tz.TZDateTime.now(tz.local)).where(mine.contains)
        : mine;
    for (final nid in pending) {
      await _plugin.cancel(id: nid);
    }
    await ledger.save(keep: const {}, within: mine);
  }

  /// Called after every event has been scheduled at start, so later refreshes today skip unchanged ones.
  static Future<void> eventsRefreshed() => _Ledger.markFresh('notif_events');

  static int _eventId(String key) => 300000 + _hash(key) % 4000 * 2;

  static int _hash(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// Two notification ids per reminder key, stable across app starts and clear of the other ranges.
  static int _quotaId(String key) => 200000 + _hash(key) % 4000 * 2;

  /// Monthly reminders for a temple booking quota that usually opens on [day] at [hour]:[minute]
  /// India time: one the evening before and one 90 minutes ahead. Android may deliver an inexact
  /// alarm up to an hour late, so 90 minutes keeps the second one ahead of the opening.
  static Future<void> scheduleQuota(
    String key, {
    required int day,
    required int hour,
    required int minute,
    required String temple,
    required String service,
    required String lang,
  }) async {
    await cancelQuota(key);
    final india = tz.getLocation('Asia/Kolkata');
    final now = tz.TZDateTime.now(india);
    tz.TZDateTime upcoming(tz.TZDateTime Function(int month) at) {
      final t = at(now.month);
      return t.isAfter(now) ? t : at(now.month + 1);
    }

    final time = clock12(hour, minute);
    final messages = [
      (
        upcoming((m) => tz.TZDateTime(india, now.year, m, day - 1, 19)),
        switch (lang) {
          'te' => (
            '🎟️ రేపు $time · $service',
            '$temple: ఆన్‌లైన్ బుకింగ్ సాధారణంగా రేపు మొదలవుతుంది. గుర్తింపు కార్డు వివరాలు సిద్ధంగా ఉంచుకోండి.',
          ),
          'hi' => (
            '🎟️ कल $time · $service',
            '$temple: ऑनलाइन बुकिंग आमतौर पर कल खुलती है। पहचान पत्र की जानकारी तैयार रखें।',
          ),
          _ => (
            '🎟️ ${t3(lang, 'Tomorrow $time · $service', 'कल $time · $service', 'రేపు $time · $service')}',
            t3(
              lang,
              '$temple: online booking usually opens tomorrow. Keep your ID details ready.',
              '$temple: ऑनलाइन बुकिंग आमतौर पर कल खुलती है।',
              '$temple: ఆన్‌లైన్ బుకింగ్ సాధారణంగా రేపు మొదలవుతుంది.',
            ),
          ),
        },
      ),
      (
        upcoming((m) => tz.TZDateTime(india, now.year, m, day, hour, minute).subtract(const Duration(minutes: 90))),
        switch (lang) {
          'te' => (
            '🎟️ $time కు $service',
            '$temple: కోటా సాధారణంగా ఈ రోజు విడుదలవుతుంది. దేవాలయం యాప్‌లో బుకింగ్ తెరవండి.',
          ),
          'hi' => ('🎟️ $time बजे $service', '$temple: कोटा आमतौर पर आज खुलता है। देवालय में बुकिंग खोलें।'),
          _ => (
            '🎟️ ${t3(lang, '$service opens at $time', '$time बजे $service', '$time కు $service')}',
            t3(
              lang,
              '$temple: the quota usually opens today. Open Booking in Devalay.',
              '$temple: कोटा आमतौर पर आज खुलता है।',
              '$temple: కోటా సాధారణంగా ఈ రోజు విడుదలవుతుంది.',
            ),
          ),
        },
      ),
    ];
    for (final (i, (at, (title, body))) in messages.indexed) {
      await _plugin.zonedSchedule(
        id: _quotaId(key) + i,
        scheduledDate: at,
        notificationDetails: const NotificationDetails(android: _quota),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  static Future<void> cancelQuota(String key) async {
    await _plugin.cancel(id: _quotaId(key));
    await _plugin.cancel(id: _quotaId(key) + 1);
  }
}

/// "10:00 AM" for a 24-hour time.
String clock12(int hour, int minute) =>
    '${hour % 12 == 0 ? 12 : hour % 12}:${minute.toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}';

/// What is scheduled under one key: notification id -> (time, hash of the text). A refresh sends the
/// plugin only what changed, because every plugin call rewrites its whole store on Android's main
/// thread: re-sending 45 days at each start froze the app for seconds on slow phones. Everything is
/// sent again on the first refresh of each day anyway, in case the phone dropped the alarms (a force
/// stop or an aggressive battery saver does that), so reminders still heal themselves.
class _Ledger {
  _Ledger(this.key) {
    final raw = Boxes.stats.get(key);
    exists = raw is Map;
    if (raw is! Map) return;
    _fresh = raw['day'] == _today();
    final items = raw['items'];
    if (items is Map) {
      for (final e in items.entries) {
        final v = '${e.value}'.split(':');
        final id = int.tryParse('${e.key}');
        if (id != null && v.length == 2) _items[id] = (int.parse(v[0]), int.parse(v[1]));
      }
    }
  }

  final String key;
  late final bool exists;
  bool _fresh = false;
  final _items = <int, (int, int)>{};
  final _next = <int, (int, int)>{};

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  /// Whether [id] needs sending: new, moved, reworded, or the day's full refresh is due.
  bool changed(int id, DateTime at, String text) {
    final v = (at.millisecondsSinceEpoch, _hash(text));
    _next[id] = v;
    return !_fresh || _items[id] != v;
  }

  /// Recorded ids still in the future that are no longer wanted.
  Iterable<int> futureIdsExcept(Set<int> wanted, DateTime now) => _items.entries
      .where((e) => !wanted.contains(e.key) && e.value.$1 > now.millisecondsSinceEpoch)
      .map((e) => e.key)
      .toList();

  /// Records [keep] (with what [changed] saw). With [within], only those ids are replaced and the
  /// rest of the record is kept (events share one record).
  Future<void> save({required Set<int> keep, Set<int>? within}) async {
    final out = <int, (int, int)>{
      if (within != null)
        for (final e in _items.entries)
          if (!within.contains(e.key)) e.key: e.value,
      for (final id in keep) id: ?(_next[id] ?? _items[id]),
    };
    // A shared record (events) is marked fresh by [markFresh] once every entry has been through the
    // day's refresh; a single edit keeps the day it had.
    final day = within == null ? _today() : (Boxes.stats.get(key) as Map?)?['day'];
    await Boxes.stats.put(key, {
      'day': day,
      'items': {for (final e in out.entries) '${e.key}': '${e.value.$1}:${e.value.$2}'},
    });
  }

  static Future<void> markFresh(String key) async {
    final raw = Boxes.stats.get(key);
    await Boxes.stats.put(key, {'items': raw is Map ? raw['items'] : const {}, 'day': _today()});
  }

  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }
}
