import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'calendar_reminders.dart';
import 'notifications.dart';
import 'storage.dart';
import 'usage.dart';

/// The two things that bring people back each day without opening the app first: the morning
/// Panchang notification and the home-screen Panchang widget. Turning them on goes through here so
/// every path (onboarding, the Home card, Settings, the calendar) is logged the same way.

const panchangWidgetClass = 'com.chandrachaan.devalay.PanchangWidget';

/// Prefs key: the Home card offering both was closed.
const morningCardClosedKey = 'morning_card_closed';

/// Turns the morning Panchang on or off. [source] says where ('onboarding', 'home_card',
/// 'settings', 'calendar'). Returns whether it is on afterwards: asking for the notification
/// permission can fail, and then nothing changes.
Future<bool> setMorningPanchang(WidgetRef ref, bool on, {required String source}) async {
  if (on && !await Notifications.requestPermission()) {
    Usage.record('notification_permission_denied', item: source);
    return false;
  }
  await ref.read(prefsProvider.notifier).set('panchang_daily', on);
  await refreshPanchangNotifications(ref);
  logNotificationSettings(ref.read(prefsProvider), kind: 'panchang', on: on, source: source);
  return on;
}

/// notification_settings_changed: which reminder ([kind]: panchang, prayer, festival), on or off,
/// its time, and where it was changed.
void logNotificationSettings(Prefs p, {required String kind, required bool on, required String source}) {
  final (hour, minute) = switch (kind) {
    'panchang' => (p.panchangHour, p.panchangMinute),
    'prayer' => (p.reminderHour, p.reminderMinute),
    _ => (7, 0),
  };
  Usage.record(
    'notification_settings_changed',
    item: '$kind:${on ? 'on' : 'off'}',
    params: {'kind': kind, 'enabled': on ? 1 : 0, 'hour': hour, 'minute': minute, 'source': source},
  );
  if (kind == 'panchang') Usage.property('morning_panchang', on ? 'on' : 'off');
}

/// Whether the launcher can add a widget from inside the app (Android 8+, most launchers).
Future<bool> canPinWidget() async {
  if (kIsWeb || !Platform.isAndroid) return false;
  try {
    return await HomeWidget.isRequestPinWidgetSupported() ?? false;
  } catch (_) {
    return false;
  }
}

/// How many Devalay widgets are on the home screen (0 when it can't be told).
Future<int> installedWidgetCount() async {
  if (kIsWeb || !Platform.isAndroid) return 0;
  try {
    return (await HomeWidget.getInstalledWidgets()).length;
  } catch (_) {
    return 0;
  }
}

/// Asks the launcher to place the Panchang widget; the launcher shows its own confirmation.
Future<void> pinPanchangWidget({required String source}) async {
  Usage.record('widget_pin_request', item: source, params: {'source': source});
  try {
    await HomeWidget.requestPinWidget(qualifiedAndroidName: panchangWidgetClass);
  } catch (e) {
    debugPrint('Widget pin request failed: $e');
  }
}

/// Analytics user properties, so retention can be compared for people with and without the
/// morning message ("blocked" when it is on but Android hides the app's notifications) and widgets.
Future<void> reportRetentionProperties(Prefs p) async {
  try {
    final allowed = await Notifications.allowed();
    Usage.property('morning_panchang', !p.panchangDaily ? 'off' : (allowed ? 'on' : 'blocked'));
    final widgets = await installedWidgetCount();
    Usage.property('home_widgets', widgets >= 2 ? '2+' : '$widgets');
  } catch (e) {
    debugPrint('Retention properties not reported: $e');
  }
}

/// widget_tap: which widget ("w" in its link: panchang, tithi, countdown, now) opened which screen.
void logWidgetTap(Uri uri, String route) {
  final widget = uri.queryParameters['w'] ?? 'unknown';
  Usage.record('widget_tap', item: widget, params: {'widget': widget, 'screen': route.split('/')[1]});
}

/// notification_open: which reminder ([kind]) was tapped and whether it started the app.
void logNotificationOpen(String kind, {required bool coldStart}) {
  Usage.record('notification_open', item: kind, params: {'type': kind, 'cold_start': coldStart ? 1 : 0});
}
