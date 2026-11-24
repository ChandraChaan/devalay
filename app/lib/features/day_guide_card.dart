import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day_guide.dart';
import '../core/i18n.dart';
import '../core/storage.dart';
import '../widgets/common.dart';

/// "Today's guidance": the day's direction (Disha Shool) and a few plain points on what the day
/// suits and what to avoid, from the weekday, tithi and nakshatra at sunrise, with the best and
/// worst times. Shown on the Panchang and calendar day pages.
class DayGuideCard extends ConsumerWidget {
  const DayGuideCard({super.key, required this.data});

  /// The day's panchang.
  final Map data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final scheme = Theme.of(context).colorScheme;
    final day = DateTime.tryParse('${data['date']}');
    if (day == null) return const SizedBox.shrink();
    final weekday = day.weekday;

    // The panchang comes from the network or cache: read it defensively, so a missing or odd
    // field drops a line instead of breaking the page.
    int firstIndex(String key) {
      final v = data[key];
      final first = v is List && v.isNotEmpty ? v.first : v;
      final index = first is Map ? first['index'] : null;
      return index is num ? index.toInt() : 0;
    }

    String? span(String key) {
      final v = data[key];
      final s = v is List ? (v.isEmpty ? null : v.first) : v;
      if (s is! Map || s['starts'] == null || s['ends'] == null) return null;
      return '${hhmm('${s['starts']}')} – ${hhmm('${s['ends']}')}';
    }

    final tithiIndex = firstIndex('tithi');
    final tithi = tithiIndex >= 1 && tithiIndex <= 30 ? tithiNote(lang, tithiIndex) : null;
    final nakshatra = firstIndex('nakshatra');
    final nature = nakshatra >= 1 && nakshatra <= 27 ? starNature(nakshatra) : null;
    final direction = directionLabel(lang, dishaShool(weekday));

    final good = <String>[
      weekdaySuits(lang, weekday),
      if (nature != null) ?starSuits(lang, nature),
      if (tithi != null && !tithi.avoid) tithi.text,
    ];
    final avoid = <String>[
      if (tithi != null && tithi.avoid) tithi.text,
      if (nature != null) ?starAvoid(lang, nature),
      if (span('rahu_kaal') case final rahu?)
        t3(
          lang,
          'Rahu Kaal $rahu: do not start anything important',
          'राहु काल $rahu: कोई ज़रूरी काम शुरू न करें',
          'రాహుకాలం $rahu: ముఖ్యమైన పని మొదలుపెట్టకండి',
        ),
    ];
    // Abhijit is traditionally not used on Wednesdays.
    final abhijit = weekday == DateTime.wednesday ? null : span('abhijit_muhurta');

    Widget heading(IconData icon, String text, Color color) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );

    Widget point(String text) => Padding(
      padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t3(lang, "Today's guidance", 'आज का मार्गदर्शन', 'నేటి మార్గదర్శనం'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
            ),
            heading(
              Icons.explore_rounded,
              t3(lang, 'Day direction (Disha Shool)', 'दिशा शूल', 'దిశా శూల'),
              Colors.deepOrange,
            ),
            point(
              t3(
                lang,
                'Avoid setting out on a journey towards the $direction today.',
                'आज $direction दिशा की यात्रा शुरू न करें।',
                'ఈ రోజు $direction దిశగా ప్రయాణం మొదలుపెట్టకండి.',
              ),
            ),
            point(
              t3(
                lang,
                'If you must go that way: ${dishaShoolRemedy(lang, weekday)} before leaving.',
                'जाना ज़रूरी हो तो: ${dishaShoolRemedy(lang, weekday)}।',
                'తప్పనిసరిగా వెళ్లాల్సి వస్తే: ${dishaShoolRemedy(lang, weekday)}.',
              ),
            ),
            heading(Icons.check_circle_rounded, t3(lang, 'Good for', 'इनके लिए शुभ', 'వీటికి మంచిది'), Colors.green),
            for (final g in good) point(g),
            if (avoid.isNotEmpty) ...[
              heading(Icons.block_rounded, t3(lang, 'Better to avoid', 'इनसे बचें', 'వీటిని నివారించండి'), Colors.red),
              for (final a in avoid) point(a),
            ],
            if (abhijit != null) ...[
              heading(
                Icons.wb_twilight_rounded,
                t3(lang, 'Best time to begin', 'आरंभ का सबसे अच्छा समय', 'ప్రారంభానికి ఉత్తమ సమయం'),
                Colors.teal,
              ),
              point(
                t3(
                  lang,
                  'Abhijit Muhurta $abhijit, around midday',
                  'अभिजित मुहूर्त $abhijit, दोपहर के आसपास',
                  'అభిజిత్ ముహూర్తం $abhijit, మధ్యాహ్నం',
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 120.ms);
  }
}
