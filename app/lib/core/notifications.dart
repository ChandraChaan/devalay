import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

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

  static Future<void> scheduleDaily(int hour, int minute, {required String lang}) async {
    await _plugin.cancel(id: _dailyId);
    await _plugin.zonedSchedule(
      id: _dailyId,
      scheduledDate: _next(hour, minute),
      notificationDetails: const NotificationDetails(android: _daily),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: lang == 'hi' ? '🪔 प्रार्थना का समय' : '🪔 Time for prayer',
      body: lang == 'hi' ? 'दीप जलाएँ, आज का पंचांग और गीता श्लोक देखें।' : "Light a diya and read today's Gita verse.",
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDaily() => _plugin.cancel(id: _dailyId);

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
}
