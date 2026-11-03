import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

import 'firebase.dart';
import 'theme.dart';

/// Local, on-device storage. Nothing here leaves the phone unless the user signs in
/// and syncs favourites.
class Boxes {
  static late Box prefs;
  static late Box cache;
  static late Box favorites;
  static late Box downloads;
  static late Box stats;

  static Future<void> init() async {
    await Hive.initFlutter('devalay');
    prefs = await Hive.openBox('prefs');
    cache = await Hive.openBox('http_cache');
    favorites = await Hive.openBox('favorites');
    downloads = await Hive.openBox('downloads');
    stats = await Hive.openBox('stats');
    if (prefs.get('device_id') == null) {
      await prefs.put('device_id', const Uuid().v4());
    }
  }
}

@immutable
class Prefs {
  const Prefs({
    required this.language,
    required this.themeMode,
    required this.onboarded,
    required this.ishtaDevta,
    required this.rashi,
    required this.cityId,
    required this.dailyReminder,
    required this.reminderHour,
    required this.reminderMinute,
    required this.festivalReminders,
    required this.textScale,
    required this.showTransliteration,
    required this.showMeaning,
    required this.accent,
  });

  final String language;
  final ThemeMode themeMode;
  final bool onboarded;
  final String? ishtaDevta;
  final String? rashi;
  final String cityId;
  final bool dailyReminder;
  final int reminderHour;
  final int reminderMinute;
  final bool festivalReminders;
  final double textScale;
  final bool showTransliteration;
  final bool showMeaning;
  final Accent accent;

  static Prefs load(Box box) => Prefs(
    language: box.get('language', defaultValue: 'en') as String,
    themeMode: ThemeMode.values[box.get('theme', defaultValue: 0) as int],
    onboarded: box.get('onboarded', defaultValue: false) as bool,
    ishtaDevta: box.get('ishta') as String?,
    rashi: box.get('rashi') as String?,
    cityId: box.get('city', defaultValue: 'delhi') as String,
    dailyReminder: box.get('daily_reminder', defaultValue: false) as bool,
    reminderHour: box.get('reminder_hour', defaultValue: 6) as int,
    reminderMinute: box.get('reminder_minute', defaultValue: 30) as int,
    festivalReminders: box.get('festival_reminders', defaultValue: false) as bool,
    textScale: (box.get('text_scale', defaultValue: 1.0) as num).toDouble(),
    showTransliteration: box.get('show_translit', defaultValue: false) as bool,
    showMeaning: box.get('show_meaning', defaultValue: true) as bool,
    accent: Accent.byName(box.get('accent') as String?),
  );
}

class PrefsNotifier extends Notifier<Prefs> {
  @override
  Prefs build() => Prefs.load(Boxes.prefs);

  Future<void> set(String key, Object? value) async {
    if (value == null) {
      await Boxes.prefs.delete(key);
    } else {
      await Boxes.prefs.put(key, value);
    }
    state = Prefs.load(Boxes.prefs);
  }

  Future<void> setLanguage(String v) async {
    await set('language', v);
    await FirebaseServices.subscribe(v);
  }

  Future<void> setTheme(ThemeMode m) => set('theme', m.index);
  Future<void> setAccent(Accent a) => set('accent', a.name);
  Future<void> setIshta(String? v) => set('ishta', v);
  Future<void> setRashi(String? v) => set('rashi', v);
  Future<void> setCity(String v) => set('city', v);
  Future<void> completeOnboarding() => set('onboarded', true);
}

final prefsProvider = NotifierProvider<PrefsNotifier, Prefs>(PrefsNotifier.new);

String get deviceId => Boxes.prefs.get('device_id') as String;
