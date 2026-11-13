import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n.dart';
import '../core/jyotish.dart';
import '../core/theme.dart';

/// An eclipse on the calendar's day page: type, local times of each phase and Sutak.
class EclipseCard extends StatelessWidget {
  const EclipseCard({super.key, required this.eclipse, required this.lang});
  final Eclipse eclipse;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final e = eclipse;
    String at(DateTime? t) => t == null ? '—' : dayClock(lang, t, e.date);
    final rows = <(String, String)>[
      if (e.visible) ...[
        (t3(lang, 'Begins', 'आरंभ (स्पर्श)', 'ప్రారంభం (స్పర్శ)'), at(e.begins)),
        if (e.contacts['total_begin'] case final t?)
          (t3(lang, 'Totality begins', 'पूर्णता आरंभ', 'సంపూర్ణ దశ ప్రారంభం'), at(t)),
        (t3(lang, 'Maximum', 'मध्य', 'మధ్యకాలం'), at(e.max)),
        if (e.contacts['total_end'] case final t?)
          (t3(lang, 'Totality ends', 'पूर्णता समाप्त', 'సంపూర్ణ దశ ముగింపు'), at(t)),
        (t3(lang, 'Ends', 'समाप्त (मोक्ष)', 'ముగింపు (మోక్షం)'), at(e.ends)),
        if (e.visibleFrom != e.begins || e.visibleTo != e.ends)
          (
            t3(lang, 'Seen here', 'यहाँ दिखेगा', 'ఇక్కడ కనిపించేది'),
            '${hourMinute(lang, e.visibleFrom!)} – ${hourMinute(lang, e.visibleTo!)}',
          ),
        if (e.magnitude != null) (t3(lang, 'Magnitude', 'ग्रास', 'గ్రాసం'), e.magnitude!.toStringAsFixed(2)),
        if (e.sutakStart != null) (t3(lang, 'Sutak', 'सूतक', 'సూతకం'), '${at(e.sutakStart)} – ${at(e.sutakEnd)}'),
      ],
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(e.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.title(lang),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(e.note(lang), style: Theme.of(context).textTheme.bodyMedium),
            if (rows.isNotEmpty) const Divider(height: 20),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (e.visible && e.sutakStart != null) ...[
              const SizedBox(height: 8),
              Text(
                t3(
                  lang,
                  'During Sutak, temples close and cooking and eating are avoided. Children, the elderly, the sick and '
                      'pregnant women may keep a shorter Sutak. Bathe and offer prayers after the eclipse ends.',
                  'सूतक में मंदिर बंद रहते हैं और भोजन बनाना-खाना टाला जाता है। बच्चे, बुज़ुर्ग, रोगी और गर्भवती महिलाएँ '
                      'छोटा सूतक रख सकते हैं। ग्रहण समाप्त होने पर स्नान करके पूजा करें।',
                  'సూతక సమయంలో ఆలయాలు మూసివేస్తారు, వంట చేయడం, తినడం మానుకుంటారు. పిల్లలు, వృద్ధులు, రోగులు, గర్భిణీలు '
                      'తక్కువ సూతకం పాటించవచ్చు. గ్రహణం ముగిశాక స్నానం చేసి పూజ చేయండి.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The day page's note of ceremonies with a Shubha Muhurtham on [day], linking to the full list.
class DayMuhurthamNotes extends ConsumerWidget {
  const DayMuhurthamNotes({super.key, required this.day, required this.lang});
  final DateTime day;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(muhurthamProvider).value;
    if (all == null) return const SizedBox.shrink();
    final hits = [for (final k in muhurthamKinds) ?all[k]!.where((d) => DateUtils.isSameDay(d.date, day)).firstOrNull];
    if (hits.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final d in hits)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => context.push('/muhurtham?kind=${d.kind}'),
              leading: Text(muhurthamEmoji(d.kind), style: const TextStyle(fontSize: 26)),
              title: Text(
                '${t3(lang, 'Shubha Muhurtham', 'शुभ मुहूर्त', 'శుభ ముహూర్తం')}: ${muhurthamLabel(lang, d.kind)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade700),
              ),
              subtitle: Text(windowsText(lang, d)),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
      ],
    );
  }
}

/// "10:30 AM – 1:15 PM, 2:40 PM – 6:05 AM (16 Nov)".
String windowsText(String lang, MuhurthamDay d) =>
    d.windows.map((w) => '${dayClock(lang, d.at(w.$1), d.date)} – ${dayClock(lang, d.at(w.$2), d.date)}').join(', ');

/// A small coloured chip, shared by the Muhurtham and Jatakam screens.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (color ?? Palette.saffron).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? Palette.saffron),
    ),
  );
}
