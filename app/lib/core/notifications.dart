import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
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

  static const _panchangBase = 400000;
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
      default:
        const day = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        const deity = ['Shiva', 'Hanuman', 'Ganesha', 'Vishnu', 'Lakshmi', 'Shani Dev', 'Surya'];
        return (
          "🪔 ${day[wd]} · ${deity[wd]}'s songs",
          "Listen to ${deity[wd]}'s bhajans, light a diya and see today's Panchang.",
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
        title: lang == 'hi' && f.nameHi.isNotEmpty ? '🙏 ${f.nameHi}' : '🙏 ${f.name}',
        body: f.description.isNotEmpty
            ? f.description
            : (lang == 'hi' ? 'आज का पर्व मंगलमय हो!' : 'Wishing you a blessed festival!'),
      );
    }
  }

  static Future<void> cancelFestivals() async {
    for (var i = 0; i < 30; i++) {
      await _plugin.cancel(id: _festivalBase + i);
    }
  }

  /// One morning message per day for the coming days ([panchangDays] at most). Each day's
  /// text differs, so these are one-off alarms re-laid each time the app opens.
  static Future<void> schedulePanchang(
    List<({DateTime day, String title, String body})> items, {
    required int hour,
    required int minute,
  }) async {
    await cancelPanchang();
    final now = tz.TZDateTime.now(tz.local);
    var i = 0;
    for (final item in items.take(panchangDays)) {
      final when = _next(hour, minute, item.day);
      if (!when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: _panchangBase + i++,
        scheduledDate: when,
        notificationDetails: _expanded(_panchang, item.body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: item.title,
        body: item.body,
      );
    }
  }

  static Future<void> cancelPanchang() async {
    for (var i = 0; i < panchangDays; i++) {
      await _plugin.cancel(id: _panchangBase + i);
    }
  }

  /// A personal event: the evening before (7 PM) and the morning of (7 AM).
  static Future<void> scheduleEvent(
    String id, {
    required DateTime on,
    required (String, String) eve,
    required (String, String) morning,
  }) async {
    await cancelEvent(id);
    final now = tz.TZDateTime.now(tz.local);
    final slots = [(_next(19, 0, on.subtract(const Duration(days: 1))), eve), (_next(7, 0, on), morning)];
    for (final (i, (at, (title, body))) in slots.indexed) {
      if (!at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: _eventId(id) + i,
        scheduledDate: at,
        notificationDetails: _expanded(_events, body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    }
  }

  static Future<void> cancelEvent(String id) async {
    await _plugin.cancel(id: _eventId(id));
    await _plugin.cancel(id: _eventId(id) + 1);
  }

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
            '🎟️ Tomorrow $time · $service',
            '$temple: online booking usually opens tomorrow. Keep your ID details ready.',
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
          _ => ('🎟️ $service opens at $time', '$temple: the quota usually opens today. Open Booking in Devalay.'),
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
