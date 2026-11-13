import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'events.dart';
import 'i18n.dart';
import 'models.dart';
import 'muhurta.dart';
import 'names.dart';
import 'providers.dart';
import 'regional.dart';
import 'storage.dart';

/// Days written ahead for the home-screen widget, so it keeps turning over offline.
const widgetDays = 30;

/// The widget's text for one day, already in the user's language.
Map<String, String> widgetDay(String lang, DateTime day, Map s, List<Festival> festivals, List<UserEvent> events) {
  final month = shownMonthOf(monthSystemFor(lang), s);
  final tithi = s['tithi_index'] as int?;
  final star = nakshatraNames.indexOf('${s['nakshatra']}');
  String? rahu;
  if (s['sunset'] != null) {
    final (a, b) = rahuKalam(day, wallClock('${s['sunrise']}'), wallClock('${s['sunset']}'));
    rahu = '${t3(lang, 'Rahu Kalam', 'राहु काल', 'రాహు కాలం')}: ${clock(a)} – ${clock(b)}';
  }
  final major = festivals.where((f) => f.major).map((f) => '🪔 ${f.label(lang)}');
  final minor = festivals.where((f) => !f.major).map((f) => '🙏 ${f.label(lang)}');
  final mine = events.map((e) => '${e.emoji} ${e.title}');
  final yoga = shubhYoga(day, '${s['nakshatra']}');
  final first = [
    for (final e in events) (e.emoji, e.title),
    for (final f in festivals.where((f) => f.major)) ('🪔', f.label(lang)),
    for (final f in festivals.where((f) => !f.major)) ('🙏', f.label(lang)),
  ].firstOrNull;
  return {
    'day': '${day.day}',
    'weekday': fmtDate(lang, 'EEEE', day),
    'month': [fmtDate(lang, 'MMMM y', day), if (month != null) shownMonthLabel(lang, month)].join(' · '),
    'tithi': tithi == null ? '' : tithiName(lang, tithi),
    'star': star < 0 ? '' : '${t3(lang, 'Nakshatra', 'नक्षत्र', 'నక్షత్రం')}: ${nakshatraLabel(lang, star)}',
    'rahu': rahu ?? '',
    'festival': [...mine, ...major, ...minor, if (yoga != null) '✨ ${shubhYogaLabel(lang, yoga)}'].take(2).join('  '),
    // The small tithi widget: a short date and one mark for the day's first event or festival.
    'date_short': fmtDate(lang, 'EEE, d MMM', day),
    'mark': first?.$1 ?? '',
    'mark_text': first?.$2 ?? '',
  };
}

/// An emoji for a festival on the countdown widget.
String festivalEmoji(Festival f) {
  final s = f.slug;
  bool has(String part) => s.contains(part);
  if (has('diwali') || has('dhanteras') || has('narak') || has('kartik-purnima')) return '🪔';
  if (has('holi')) return '🎨';
  if (has('ganesh') || has('sankashti') || has('anant-chaturdashi')) return '🐘';
  if (has('janmashtami') || has('gita') || has('govardhan')) return '🦚';
  if (has('ram-navami') || has('dussehra') || has('vivah-panchami')) return '🏹';
  if (has('shivratri') || has('pradosh')) return '🔱';
  if (has('navratri') || has('durga') || has('bathukamma')) return '🌺';
  if (has('raksha') || has('bhai-dooj')) return '🧵';
  if (has('sankranti') || has('bhogi') || has('kanuma') || has('pongal')) return '🌾';
  if (has('ugadi') || has('vasant')) return '🌿';
  if (has('hanuman')) return '🚩';
  if (has('naga') || has('nag-')) return '🐍';
  if (has('rath')) return '🛕';
  if (has('purnima')) return '🌕';
  if (has('ekadashi')) return '🙏';
  if (has('chhath') || has('ratha-saptami')) return '🌅';
  if (has('lakshmi') || has('akshaya')) return '🪙';
  return '🪔';
}

/// The next major festivals from [today] for the countdown widget, soonest first, one per day.
List<Map<String, String>> countdownEntries(String lang, Iterable<Festival> festivals, DateTime today, {int max = 24}) {
  final t = DateUtils.dateOnly(today);
  final sorted = festivals.where((f) => f.major && !DateUtils.dateOnly(f.date).isBefore(t)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final seen = <DateTime>{};
  return [
    for (final f in sorted)
      if (seen.add(DateUtils.dateOnly(f.date)))
        {
          'date': DateFormat('yyyy-MM-dd').format(f.date),
          'when': fmtDate(lang, 'd MMM', f.date),
          'name': f.label(lang),
          'emoji': festivalEmoji(f),
        },
  ].take(max).toList();
}

/// Rahu Kalam and the day's sixteen Choghadiyas for the "now" widget. Start and end are epoch
/// milliseconds, so the widget compares them with the phone clock; the times shown are the city's.
Map<String, Object> widgetNowDay(String lang, DateTime day, Map s, {String? nextSunrise}) {
  final iso = '${s['sunrise']}';
  final rise = wallClock(iso);
  final set = wallClock('${s['sunset']}');
  final next = nextSunrise != null ? wallClock(nextSunrise) : rise.add(const Duration(days: 1));
  final offset = isoOffset(iso);
  int ms(DateTime wall) => wall.subtract(offset).millisecondsSinceEpoch;
  final (a, b) = rahuKalam(day, rise, set);
  return {
    'rahu': [ms(a), ms(b), '${clock(a)} – ${clock(b)}'],
    'periods': [
      for (final p in choghadiya(day, rise, set, next))
        [ms(p.start), ms(p.end), choghadiyaLabel(lang, p.key), p.quality.name, clock(p.end)],
    ],
  };
}

/// The words the native widgets put around the data, in the user's language.
Map<String, String> widgetLabels(String lang) => {
  'empty': t3(
    lang,
    "Open Devalay to load today's Panchang",
    'आज का पंचांग देखने के लिए देवालय खोलें',
    'నేటి పంచాంగం కోసం దేవాలయం తెరవండి',
  ),
  'next_festival': t3(lang, 'Next festival', 'अगला त्योहार', 'తదుపరి పండుగ'),
  'today': t3(lang, 'Today', 'आज', 'ఈరోజు'),
  'tomorrow': t3(lang, 'Tomorrow', 'कल', 'రేపు'),
  'in_days': t3(lang, 'In {0} days', '{0} दिन बाकी', '{0} రోజుల్లో'),
  'choghadiya': t3(lang, 'Choghadiya now', 'अभी का चौघड़िया', 'ఇప్పటి చౌఘడియ'),
  'rahu': t3(lang, 'Rahu Kalam', 'राहु काल', 'రాహు కాలం'),
  'rahu_now': t3(lang, 'Rahu Kalam now', 'अभी राहु काल', 'ఇప్పుడు రాహు కాలం'),
  'rahu_over': t3(lang, 'Rahu Kalam is over for today', 'आज का राहु काल बीत गया', 'నేటి రాహు కాలం ముగిసింది'),
  'until': t3(lang, 'until {0}', '{0} तक', '{0} వరకు'),
  for (final q in Quality.values) q.name: qualityLabel(lang, q),
};

/// The home-screen widgets, by their Android receiver class.
const _widgets = ['PanchangWidget', 'TithiWidget', 'FestivalCountdownWidget', 'NowWidget'];

/// Writes the coming [widgetDays] days for the Android home-screen widgets and redraws them.
Future<void> syncHomeWidget(WidgetRef ref) async {
  if (!Platform.isAndroid) return;
  try {
    final lang = ref.read(prefsProvider).language;
    final today = DateUtils.dateOnly(DateTime.now());
    final last = today.add(const Duration(days: widgetDays - 1));
    final summaries = <String, Map>{};
    for (var m = DateTime(today.year, today.month); !m.isAfter(last); m = DateTime(m.year, m.month + 1)) {
      final days = await ref
          .read(monthProvider((year: m.year, month: m.month)).future)
          .catchError((Object _) => const <Map>[]);
      for (final d in days) {
        summaries['${d['date']}'] = d;
      }
    }
    // Next year too, so the festival countdown reaches past December.
    final allFestivals = <Festival>[];
    final festivals = <DateTime, List<Festival>>{};
    for (final y in {today.year, last.year, today.year + 1}) {
      final list = await ref.read(festivalsProvider(y).future).catchError((Object _) => const <Festival>[]);
      allFestivals.addAll(list);
      for (final f in list) {
        festivals.putIfAbsent(DateUtils.dateOnly(f.date), () => []).add(f);
      }
    }
    final events = {
      for (final y in {today.year, last.year}) ...ref.read(eventsByDayProvider(y)),
    };
    final out = <String, Map<String, String>>{};
    final now = <String, Map<String, Object>>{};
    String key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    for (var day = today; !day.isAfter(last); day = DateTime(day.year, day.month, day.day + 1)) {
      final s = summaries[key(day)];
      if (s == null) continue;
      out[key(day)] = widgetDay(lang, day, s, festivals[day] ?? const [], events[day] ?? const []);
      if (s['sunrise'] != null && s['sunset'] != null) {
        final next = summaries[key(DateTime(day.year, day.month, day.day + 1))]?['sunrise'];
        now[key(day)] = widgetNowDay(lang, day, s, nextSunrise: next?.toString());
      }
    }
    final labels = widgetLabels(lang);
    await HomeWidget.saveWidgetData<String>('panchang_days', jsonEncode(out));
    await HomeWidget.saveWidgetData<String>('panchang_empty', labels['empty']);
    await HomeWidget.saveWidgetData<String>('widget_labels', jsonEncode(labels));
    await HomeWidget.saveWidgetData<String>('countdown', jsonEncode(countdownEntries(lang, allFestivals, today)));
    await HomeWidget.saveWidgetData<String>('now_days', jsonEncode(now));
    for (final w in _widgets) {
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.chandrachaan.devalay.$w');
    }
  } catch (_) {
    // No widget host or no data yet: the next app start tries again.
  }
}
