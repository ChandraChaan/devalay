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
import 'storage.dart';

/// Days written ahead for the home-screen widget, so it keeps turning over offline.
const widgetDays = 30;

/// The widget's text for one day, already in the user's language.
Map<String, String> widgetDay(String lang, DateTime day, Map s, List<Festival> festivals, List<UserEvent> events) {
  final month = s['lunar_month'] as int?;
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
  return {
    'day': '${day.day}',
    'weekday': fmtDate(lang, 'EEEE', day),
    'month': [fmtDate(lang, 'MMMM y', day), if (month != null) lunarMonthLabel(lang, month)].join(' · '),
    'tithi': tithi == null ? '' : tithiName(lang, tithi),
    'star': star < 0 ? '' : '${t3(lang, 'Nakshatra', 'नक्षत्र', 'నక్షత్రం')}: ${nakshatraLabel(lang, star)}',
    'rahu': rahu ?? '',
    'festival': [...mine, ...major, ...minor, if (yoga != null) '✨ ${shubhYogaLabel(lang, yoga)}'].take(2).join('  '),
  };
}

/// Writes the coming [widgetDays] days for the Android home-screen widget and redraws it.
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
    final festivals = <DateTime, List<Festival>>{};
    for (final y in {today.year, last.year}) {
      final list = await ref.read(festivalsProvider(y).future).catchError((Object _) => const <Festival>[]);
      for (final f in list) {
        festivals.putIfAbsent(DateUtils.dateOnly(f.date), () => []).add(f);
      }
    }
    final events = {
      for (final y in {today.year, last.year}) ...ref.read(eventsByDayProvider(y)),
    };
    final out = <String, Map<String, String>>{};
    for (var day = today; !day.isAfter(last); day = DateTime(day.year, day.month, day.day + 1)) {
      final key = DateFormat('yyyy-MM-dd').format(day);
      final s = summaries[key];
      if (s == null) continue;
      out[key] = widgetDay(lang, day, s, festivals[day] ?? const [], events[day] ?? const []);
    }
    await HomeWidget.saveWidgetData<String>('panchang_days', jsonEncode(out));
    await HomeWidget.saveWidgetData<String>(
      'panchang_empty',
      t3(
        lang,
        "Open Devalay to load today's Panchang",
        'आज का पंचांग देखने के लिए देवालय खोलें',
        'నేటి పంచాంగం కోసం దేవాలయం తెరవండి',
      ),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: 'com.chandrachaan.devalay.PanchangWidget');
  } catch (_) {
    // No widget host or no data yet: the next app start tries again.
  }
}
