import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/events.dart';
import '../core/i18n.dart';
import '../core/jyotish.dart';
import '../core/muhurta.dart';
import '../core/names.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'my_events.dart';

typedef _Day = ({DateTime date, String emoji, String title, String? note, bool major});

/// Year lists of festivals, vratas, full and new moons, auspicious yogas, holidays and the
/// user's own days, the way printed Telugu calendars list "important days".
class ImportantDaysScreen extends ConsumerStatefulWidget {
  const ImportantDaysScreen({super.key});
  @override
  ConsumerState<ImportantDaysScreen> createState() => _ImportantDaysScreenState();
}

class _ImportantDaysScreenState extends ConsumerState<ImportantDaysScreen> {
  static const _filters = [
    'festivals',
    'ekadashi',
    'purnima',
    'amavasya',
    'pradosh',
    'sankashti',
    'masik-shivratri',
    'shubh',
    'eclipses',
    'holidays',
    'mine',
  ];

  final _thisYear = DateTime.now().year;
  late int _year = _thisYear;
  late String _filter = _filters.contains(Boxes.prefs.get('important_filter'))
      ? Boxes.prefs.get('important_filter') as String
      : 'festivals';
  bool _showPast = false;
  bool _searching = false;
  String _q = '';

  /// Everything in the year whose name matches the search, in English or the chosen language.
  List<_Day>? _search(String lang) {
    final q = _q.trim().toLowerCase();
    final festivals = ref.watch(festivalsProvider(_year)).value;
    if (festivals == null) return null;
    bool match(String a, [String b = '']) => a.toLowerCase().contains(q) || b.toLowerCase().contains(q);
    return [
      for (final f in festivals)
        if (match(f.label(lang), '${f.name} ${f.nameHi} ${f.deity}'))
          (
            date: DateUtils.dateOnly(f.date),
            emoji: f.major ? '🪔' : _emoji(f.kind == 'festival' ? 'festivals' : f.kind),
            title: f.label(lang),
            note: f.description.isEmpty ? null : f.describe(lang),
            major: f.major,
          ),
      for (final (m, d) in const [(1, 26), (8, 15), (10, 2), (12, 25)])
        if (match(
          holidayLabel(lang, nationalHoliday(DateTime(_year, m, d))!),
          holidayLabel('en', nationalHoliday(DateTime(_year, m, d))!),
        ))
          (
            date: DateTime(_year, m, d),
            emoji: '🇮🇳',
            title: holidayLabel(lang, nationalHoliday(DateTime(_year, m, d))!),
            note: null,
            major: true,
          ),
      for (final MapEntry(key: date, value: events) in ref.watch(eventsByDayProvider(_year)).entries)
        for (final e in events)
          if (match(e.title)) (date: date, emoji: e.emoji, title: e.title, note: null, major: true),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  String _label(String lang, String f) => switch (f) {
    'festivals' => t3(lang, 'Festivals', 'त्योहार', 'పండుగలు'),
    'ekadashi' => t3(lang, 'Ekadashi', 'एकादशी', 'ఏకాదశి'),
    'purnima' => t3(lang, 'Purnima', 'पूर्णिमा', 'పౌర్ణమి'),
    'amavasya' => t3(lang, 'Amavasya', 'अमावस्या', 'అమావాస్య'),
    'pradosh' => t3(lang, 'Pradosham', 'प्रदोष', 'ప్రదోషం'),
    'sankashti' => t3(lang, 'Sankashti', 'संकष्टी', 'సంకటహర చవితి'),
    'masik-shivratri' => t3(lang, 'Masa Shivaratri', 'मासिक शिवरात्रि', 'మాస శివరాత్రి'),
    'shubh' => t3(lang, 'Auspicious days', 'शुभ योग', 'శుభ యోగాలు'),
    'eclipses' => t3(lang, 'Eclipses', 'ग्रहण', 'గ్రహణాలు'),
    'holidays' => t3(lang, 'Holidays', 'अवकाश', 'సెలవులు'),
    _ => t3(lang, 'My events', 'मेरे दिन', 'నా రోజులు'),
  };

  String _emoji(String f) => switch (f) {
    'festivals' => '🪔',
    'ekadashi' => '🙏',
    'purnima' => '🌕',
    'amavasya' => '🌑',
    'pradosh' || 'masik-shivratri' => '🔱',
    'sankashti' => '🐘',
    'shubh' => '✨',
    'eclipses' => '🌘',
    'holidays' => '🇮🇳',
    _ => '🎂',
  };

  List<_Day>? _days(String lang) {
    switch (_filter) {
      case 'festivals' || 'ekadashi' || 'purnima' || 'amavasya' || 'pradosh' || 'sankashti' || 'masik-shivratri':
        final all = ref.watch(festivalsProvider(_year)).value;
        if (all == null) return null;
        final kind = _filter == 'festivals' ? 'festival' : _filter;
        return [
          for (final f in all)
            if (f.kind == kind || (_filter == 'ekadashi' && f.kind == 'festival' && f.slug.contains('ekadashi')))
              (
                date: DateUtils.dateOnly(f.date),
                emoji: f.major ? '🪔' : _emoji(_filter),
                title: f.label(lang),
                note: f.description.isEmpty ? null : f.describe(lang),
                major: f.major,
              ),
        ]..sort((a, b) => a.date.compareTo(b.date));
      case 'shubh':
        final days = ref.watch(yearDaysProvider(_year)).value;
        if (days == null) return null;
        return [
          for (final d in days)
            if (shubhYoga(DateTime.parse('${d['date']}'), '${d['nakshatra']}') case final y?)
              (
                date: DateTime.parse('${d['date']}'),
                emoji: '✨',
                title: shubhYogaLabel(lang, y),
                note: shubhYogaNote(lang, y),
                major: y != 'amrita-siddhi',
              ),
        ];
      case 'eclipses':
        final eclipses = ref.watch(eclipsesProvider);
        if (eclipses.isLoading) return null;
        return [
          for (final e in eclipses.value ?? const <Eclipse>[])
            if (e.date.year == _year)
              (date: e.day, emoji: e.emoji, title: e.title(lang), note: e.note(lang), major: e.visible),
        ];
      case 'holidays':
        return [
          for (final (m, d) in const [(1, 26), (8, 15), (10, 2), (12, 25)])
            (
              date: DateTime(_year, m, d),
              emoji: '🇮🇳',
              title: holidayLabel(lang, nationalHoliday(DateTime(_year, m, d))!),
              note: null,
              major: true,
            ),
        ];
      default:
        final byDay = ref.watch(eventsByDayProvider(_year));
        return [
          for (final MapEntry(key: date, value: events) in byDay.entries)
            for (final e in events)
              (
                date: date,
                emoji: e.emoji,
                title: e.title,
                note: [
                  UserEvent.kindLabel(lang, e.kind),
                  if (e.repeat == EventRepeat.tithi) e.tithiLabel(lang),
                ].join(' · '),
                major: true,
              ),
        ]..sort((a, b) => a.date.compareTo(b.date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final today = DateUtils.dateOnly(DateTime.now());
    final all = _q.trim().isEmpty ? _days(lang) : _search(lang);
    final hidePast = _year == _thisYear && !_showPast && _q.trim().isEmpty;
    final items = all?.where((d) => !hidePast || !d.date.isBefore(today)).toList();
    final hidden = (all?.length ?? 0) - (items?.length ?? 0);
    final nextUp = items?.where((d) => !d.date.isBefore(today)).firstOrNull;

    final byMonth = <int, List<_Day>>{};
    for (final d in items ?? const <_Day>[]) {
      byMonth.putIfAbsent(d.date.month, () => []).add(d);
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: t3(
                    lang,
                    'Search festivals, e.g. Diwali',
                    'त्योहार खोजें, जैसे दिवाली',
                    'పండుగ వెతకండి, ఉదా: దీపావళి',
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              )
            : Text(t3(lang, 'Important days', 'महत्वपूर्ण दिन', 'ముఖ్యమైన రోజులు')),
        actions: [
          IconButton(
            tooltip: t3(lang, 'Search', 'खोजें', 'వెతకండి'),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _q = '';
            }),
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _filter == 'mine'
          ? FloatingActionButton.extended(
              onPressed: () => showEventEditor(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(t3(lang, 'Add', 'जोड़ें', 'జోడించు')),
            )
          : null,
      body: Column(
        children: [
          if (_q.trim().isEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final y in [_thisYear, _thisYear + 1])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: _year == y ? const Icon(Icons.event_rounded, size: 16) : null,
                        label: Text('$y'),
                        selected: _year == y,
                        onSelected: (_) => setState(() => _year = y),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: VerticalDivider(width: 1),
                  ),
                  const SizedBox(width: 8),
                  for (final f in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text('${_emoji(f)} ${_label(lang, f)}'),
                        selected: _filter == f,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = f);
                          Boxes.prefs.put('important_filter', f);
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: items == null
                ? const LoadingList()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    children: [
                      if (hidden > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() => _showPast = true),
                            icon: const Icon(Icons.history_rounded, size: 18),
                            label: Text(
                              t3(lang, 'Show $hidden earlier', '$hidden पिछले दिखाएँ', 'గడిచిన $hidden చూపించు'),
                            ),
                          ),
                        ),
                      if (nextUp != null) _NextUp(day: nextUp, lang: lang, today: today),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _filter == 'mine'
                                ? t3(
                                    lang,
                                    'No events yet. Add birthdays, anniversaries and remembrance days.',
                                    'अभी कोई दिन नहीं। जन्मदिन, सालगिरह और श्राद्ध जोड़ें।',
                                    'ఇంకా ఏమీ లేవు. పుట్టినరోజులు, పెళ్లి రోజులు, తద్దినాలు జోడించండి.',
                                  )
                                : t3(lang, 'Nothing to show.', 'कुछ नहीं मिला।', 'ఏమీ లేవు.'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final MapEntry(key: month, value: list) in byMonth.entries) ...[
                        SectionHeader(fmtDate(lang, 'MMMM y', DateTime(_year, month))),
                        for (final (i, d) in list.indexed)
                          _Tile(day: d, lang: lang, today: today)
                              .animate(delay: (25 * i.clamp(0, 12)).ms)
                              .fadeIn(duration: 220.ms)
                              .slideX(begin: 0.04, curve: Curves.easeOut),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The first coming day of the chosen list, in the app's sunrise gradient.
class _NextUp extends StatelessWidget {
  const _NextUp({required this.day, required this.lang, required this.today});
  final _Day day;
  final String lang;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final away = day.date.difference(today).inDays;
    final weekday = fmtDate(lang, 'EEEE', day.date);
    final month = lang == 'en' ? DateFormat('MMM').format(day.date).toUpperCase() : fmtDate(lang, 'MMMM', day.date);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: GradientCard(
        colors: Palette.sunrise,
        onTap: () => context.push('/calendar/day/${DateFormat('yyyy-MM-dd').format(day.date)}'),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  '${day.date.day}',
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1),
                ),
                Text(
                  month,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (away) {
                    0 => t3(lang, 'Today', 'आज', 'ఈరోజు'),
                    1 => t3(lang, 'Tomorrow', 'कल', 'రేపు'),
                    _ => t3(lang, 'Next · in $away days', 'अगला · $away दिन में', 'తదుపరి · $away రోజుల్లో'),
                  }, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                  Text(
                    '${day.emoji} ${day.title}',
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  Text(weekday, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.day, required this.lang, required this.today});
  final _Day day;
  final String lang;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final away = day.date.difference(today).inDays;
    final past = away < 0;
    final scheme = Theme.of(context).colorScheme;
    final weekday = lang == 'te' ? teluguWeekdays[day.date.weekday - 1] : fmtDate(lang, 'EEE', day.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/calendar/day/${DateFormat('yyyy-MM-dd').format(day.date)}'),
        leading: Container(
          width: 50,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: day.major && !past ? const LinearGradient(colors: Palette.sunrise) : null,
            color: day.major && !past ? null : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${day.date.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: day.major && !past ? Colors.white : null,
                ),
              ),
              FittedBox(
                child: Text(weekday, style: TextStyle(fontSize: 10, color: day.major && !past ? Colors.white70 : null)),
              ),
            ],
          ),
        ),
        title: Text(
          '${day.emoji} ${day.title}',
          style: TextStyle(fontWeight: FontWeight.w700, color: past ? scheme.outline : null),
        ),
        subtitle: day.note == null ? null : Text(day.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: past ? null : DaysLeft(away, lang: lang),
      ),
    );
  }
}
