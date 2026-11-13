import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'events.dart';
import 'home_widget_sync.dart';
import 'i18n.dart';
import 'models.dart';
import 'muhurta.dart';
import 'names.dart';
import 'notifications.dart';
import 'providers.dart';
import 'regional.dart';
import 'storage.dart';

/// Lays out the calendar's on-device alarms: the morning Panchang message for the coming
/// weeks and each personal event's next reminder. Alarms only reach as far as the data the
/// phone has, so this runs on every app start and whenever events or settings change.
Future<void> refreshCalendarReminders(WidgetRef ref) async {
  try {
    await refreshPanchangNotifications(ref);
    await refreshEventReminders(ref);
    await syncHomeWidget(ref);
  } catch (_) {
    // Offline with nothing cached yet: the next start tries again.
  }
}

Future<List<Map>> _days(WidgetRef ref, int year) =>
    ref.read(yearDaysProvider(year).future).catchError((Object _) => <Map>[]);

Future<List<Map>> _monthDays(WidgetRef ref, DateTime m) =>
    ref.read(monthProvider((year: m.year, month: m.month)).future).catchError((Object _) => <Map>[]);

Future<List<Festival>> _festivals(WidgetRef ref, int year) =>
    ref.read(festivalsProvider(year).future).catchError((Object _) => <Festival>[]);

String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

Future<void> refreshPanchangNotifications(WidgetRef ref) async {
  final prefs = ref.read(prefsProvider);
  if (!prefs.panchangDaily) {
    await Notifications.cancelPanchang();
    return;
  }
  final lang = prefs.language;
  final today = DateUtils.dateOnly(DateTime.now());
  final last = today.add(const Duration(days: Notifications.panchangDays - 1));

  final summaries = <String, Map>{};
  for (var m = DateTime(today.year, today.month); !m.isAfter(last); m = DateTime(m.year, m.month + 1)) {
    for (final d in await _monthDays(ref, m)) {
      summaries['${d['date']}'] = d;
    }
  }
  final festivals = <DateTime, List<Festival>>{};
  for (final y in {today.year, last.year}) {
    for (final f in await _festivals(ref, y)) {
      festivals.putIfAbsent(DateUtils.dateOnly(f.date), () => []).add(f);
    }
  }
  final events = {
    for (final y in {today.year, last.year}) ...ref.read(eventsByDayProvider(y)),
  };

  final items = <({DateTime day, String title, String body})>[];
  for (var day = today; !day.isAfter(last); day = DateTime(day.year, day.month, day.day + 1)) {
    final s = summaries[_iso(day)];
    if (s == null) continue;
    items.add(
      panchangMessage(lang, day, s, festivals[day] ?? const [], events[day] ?? const [], birthStar: prefs.birthStar),
    );
  }
  await Notifications.schedulePanchang(items, hour: prefs.panchangHour, minute: prefs.panchangMinute);
}

/// Title and body of one morning message, from that day's month-summary entry.
({DateTime day, String title, String body}) panchangMessage(
  String lang,
  DateTime day,
  Map s,
  List<Festival> festivals,
  List<UserEvent> events, {
  int? birthStar,
}) {
  final weekday = fmtDate(lang, 'EEEE', day);
  final date = fmtDate(lang, 'd MMM', day);
  final major = festivals.where((f) => f.major).toList();
  final title = major.isNotEmpty
      ? '🪔 ${major.map((f) => f.label(lang)).join(' · ')} · $weekday'
      : '🌅 ${t3(lang, "Today's Panchang", 'आज का पंचांग', 'నేటి పంచాంగం')} · $weekday, $date';

  final month = shownMonthOf(monthSystemFor(lang), s);
  final tithi = s['tithi_index'] as int?;
  final nakshatra = '${s['nakshatra']}';
  final starIndex = nakshatraNames.indexOf(nakshatra);
  final lines = <String>[
    [if (month != null) shownMonthLabel(lang, month), if (tithi != null) tithiName(lang, tithi)].join(' '),
    '${t3(lang, 'Nakshatra', 'नक्षत्र', 'నక్షత్రం')}: ${nakshatraIn(lang, nakshatra)}',
  ];
  if (s['sunset'] != null) {
    final (from, to) = rahuKalam(day, wallClock('${s['sunrise']}'), wallClock('${s['sunset']}'));
    lines.add('${t3(lang, 'Rahu Kalam', 'राहु काल', 'రాహు కాలం')}: ${clock(from)} – ${clock(to)}');
  }
  if (shubhYoga(day, nakshatra) case final y?) lines.add('✨ ${shubhYogaLabel(lang, y)}');
  if (birthStar != null && starIndex >= 0) {
    final t = tarabalam(birthStar, starIndex);
    lines.add(
      '🌟 ${t3(lang, 'Your Tarabalam', 'आपका तारा बल', 'మీ తారాబలం')}: ${taraLabel(lang, t.key)} (${qualityLabel(lang, t.quality)})',
    );
  }
  for (final f in festivals.where((f) => !f.major)) {
    lines.add('🙏 ${f.label(lang)}');
  }
  for (final e in events) {
    lines.add('${e.emoji} ${e.title}');
  }
  return (day: day, title: title, body: lines.where((l) => l.isNotEmpty).join('\n'));
}

Future<void> refreshEventReminders(WidgetRef ref) async {
  final lang = ref.read(prefsProvider).language;
  final events = ref.read(eventsProvider);
  if (events.isEmpty) return;
  final today = DateUtils.dateOnly(DateTime.now());
  final tithi = events.any((e) => e.repeat == EventRepeat.tithi);
  final thisYear = tithi ? await _days(ref, today.year) : const <Map>[];
  final nextYear = tithi ? await _days(ref, today.year + 1) : const <Map>[];
  for (final e in events) {
    await scheduleEventReminder(e, lang, thisYear: thisYear, nextYear: nextYear);
  }
  await Notifications.eventsRefreshed();
}

Future<void> scheduleEventReminder(
  UserEvent e,
  String lang, {
  required List<Map> thisYear,
  required List<Map> nextYear,
}) async {
  final on = e.remind ? nextOccurrence(e, DateTime.now(), thisYear, nextYear) : null;
  if (on == null) {
    await Notifications.cancelEvent(e.id);
    return;
  }
  final detail = [
    UserEvent.kindLabel(lang, e.kind),
    if (e.repeat == EventRepeat.tithi) e.tithiLabel(lang),
    fmtDate(lang, 'EEE, d MMM', on),
  ].join(' · ');
  await Notifications.scheduleEvent(
    e.id,
    on: on,
    eve: ('${e.emoji} ${t3(lang, 'Tomorrow', 'कल', 'రేపు')}: ${e.title}', detail),
    morning: ('${e.emoji} ${t3(lang, 'Today', 'आज', 'ఈరోజు')}: ${e.title}', detail),
  );
}
