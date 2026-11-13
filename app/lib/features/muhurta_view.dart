import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/glossary.dart';
import '../core/muhurta.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Choghadiya, Hora and Gowri Panchangam for one day, with the running period marked.
class MuhurtaTimings extends ConsumerStatefulWidget {
  const MuhurtaTimings({super.key, required this.data});

  /// The day's panchang (needs date, sunrise and sunset).
  final Map data;

  @override
  ConsumerState<MuhurtaTimings> createState() => _MuhurtaTimingsState();
}

class _MuhurtaTimingsState extends ConsumerState<MuhurtaTimings> {
  static const _tabs = ['choghadiya', 'hora', 'gowri'];
  late String _tab = _tabs.contains(Boxes.prefs.get('muhurta_tab'))
      ? Boxes.prefs.get('muhurta_tab') as String
      : 'choghadiya';
  bool? _night;

  void _setTab(String t) {
    HapticFeedback.selectionClick();
    setState(() => _tab = t);
    Boxes.prefs.put('muhurta_tab', t);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final data = widget.data;
    final day = DateTime.parse('${data['date']}');
    final sunrise = wallClock('${data['sunrise']}');
    final sunset = wallClock('${data['sunset']}');

    // Tomorrow's sunrise from the month summary when cached; a day after today's is within a minute or two.
    final next = DateTime(day.year, day.month, day.day + 1);
    final nextIso = '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    final summary = ref.watch(monthProvider((year: next.year, month: next.month))).value ?? const <Map>[];
    final nextRise = summary.where((d) => d['date'] == nextIso).firstOrNull?['sunrise'];
    final nextSunrise = nextRise != null ? wallClock('$nextRise') : sunrise.add(const Duration(days: 1));

    final periods = switch (_tab) {
      'hora' => hora(day, sunrise, sunset, nextSunrise),
      'gowri' => gowri(day, sunrise, sunset, nextSunrise),
      _ => choghadiya(day, sunrise, sunset, nextSunrise),
    };
    final now = nowIn('${data['sunrise']}');
    final current = periods.where((p) => p.contains(now)).firstOrNull;
    final night = _night ?? (current?.night ?? false);
    final shown = periods.where((p) => p.night == night).toList();

    String label(Period p) => switch (_tab) {
      'hora' => horaLabel(lang, p.key),
      'gowri' => gowriLabel(lang, p.key),
      _ => choghadiyaLabel(lang, p.key),
    };

    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Color tone(Quality q) => qualityColor(q, dark: dark, neutral: scheme.outline);
    final upcoming = current == null ? null : periods.skipWhile((p) => !identical(p, current)).skip(1).firstOrNull;
    final nowWord = t3(lang, 'Now', 'अभी', 'ఇప్పుడు');
    return Card(
      margin: const EdgeInsets.only(top: 12, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    t3(lang, 'Muhurta timings', 'मुहूर्त समय', 'ముహూర్త సమయాలు'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                  MeaningButton(_tab, lang: lang),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (current != null) ...[
              _NowBanner(
                now: '$nowWord · ${label(current)}',
                detail:
                    '${qualityLabel(lang, current.quality)} · ${t3(lang, 'till', 'तक', 'వరకు')} ${clock(current.end)}',
                next: upcoming == null ? null : '${label(upcoming)} · ${clock(upcoming.start)}',
                nextWord: t3(lang, 'Next', 'अगला', 'తదుపరి'),
                good: current.quality != Quality.bad,
              ),
              const SizedBox(height: 10),
            ],
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'choghadiya', label: Text(t3(lang, 'Choghadiya', 'चौघड़िया', 'చోఘడియ'))),
                ButtonSegment(value: 'hora', label: Text(t3(lang, 'Hora', 'होरा', 'హోర'))),
                ButtonSegment(value: 'gowri', label: Text(t3(lang, 'Gowri', 'गौरी', 'గౌరీ'))),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => _setTab(s.first),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (isNight, icon, text) in [
                  (false, Icons.wb_sunny_rounded, t3(lang, 'Day', 'दिन', 'పగలు')),
                  (true, Icons.nights_stay_rounded, t3(lang, 'Night', 'रात', 'రాత్రి')),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(icon, size: 16),
                      label: Text(text),
                      selected: night == isNight,
                      onSelected: (_) => setState(() => _night = isNight),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final (i, p) in shown.indexed)
              _PeriodRow(
                    time: '${clock(p.start)} – ${clock(p.end)}',
                    name: label(p),
                    note: _tab == 'hora' ? horaUse(lang, p.key) : null,
                    quality: qualityLabel(lang, p.quality),
                    color: tone(p.quality),
                    now: identical(p, current),
                    nowLabel: nowWord,
                  )
                  .animate(key: ValueKey('$_tab$night$i'), delay: (30 * i).ms)
                  .fadeIn(duration: 200.ms)
                  .slideX(begin: 0.05),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(switch (_tab) {
                'hora' => t3(
                  lang,
                  'Each hora is ruled by a planet; begin work in the hora that suits it.',
                  'हर होरा का स्वामी एक ग्रह है; कार्य उसके अनुकूल होरा में आरंभ करें।',
                  'ప్రతి హోరకు ఒక గ్రహం అధిపతి; పనికి తగిన హోరలో ప్రారంభించండి.',
                ),
                'gowri' => t3(
                  lang,
                  'Gowri Panchangam (Nalla Neram), followed in Tamil Nadu and Andhra Pradesh.',
                  'गौरी पंचांग, तमिलनाडु और आंध्र प्रदेश में प्रचलित।',
                  'గౌరీ పంచాంగం (మంచి సమయం), తమిళనాడు, ఆంధ్రప్రదేశ్‌లలో ఆచరణలో ఉంది.',
                ),
                _ => t3(
                  lang,
                  'Amrit, Shubh and Labh are best for new work; Char suits travel.',
                  'नए कार्य के लिए अमृत, शुभ, लाभ उत्तम; यात्रा के लिए चर।',
                  'కొత్త పనులకు అమృత, శుభ, లాభ ఉత్తమం; ప్రయాణానికి చర.',
                ),
              }, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tulsi greens for good periods and kumkum red for ones to avoid, lighter on the night theme.
Color qualityColor(Quality q, {required bool dark, required Color neutral}) => switch (q) {
  Quality.best => dark ? const Color(0xFF81C784) : Palette.tulsi[1],
  Quality.good => dark ? const Color(0xFFC5E1A5) : const Color(0xFF558B2F),
  Quality.neutral => neutral,
  Quality.bad => dark ? const Color(0xFFFF8A80) : Palette.vermilion,
};

/// The running period in the app's sunrise gradient, with the one after it.
class _NowBanner extends StatelessWidget {
  const _NowBanner({
    required this.now,
    required this.detail,
    required this.next,
    required this.nextWord,
    required this.good,
  });
  final String now, detail, nextWord;
  final String? next;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      colors: good ? Palette.sunrise : const [Color(0xFF5D1A0B), Color(0xFF8D2B0B), Color(0xFFB71C1C)],
      padding: 14,
      radius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(good ? Icons.wb_sunny_rounded : Icons.do_not_disturb_on_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  now,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  detail,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (next != null) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(nextWord, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  next!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.time,
    required this.name,
    required this.quality,
    required this.color,
    required this.now,
    required this.nowLabel,
    this.note,
  });
  final String time, name, quality, nowLabel;
  final String? note;
  final Color color;
  final bool now;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: now ? color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10) : null,
        borderRadius: BorderRadius.circular(12),
        border: now ? Border.all(color: color.withValues(alpha: 0.6)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: note == null ? 22 : 34,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (now) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          nowLabel,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Palette.night : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (note != null) Text(note!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(
                quality,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
