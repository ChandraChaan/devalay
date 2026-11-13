import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gochara.dart';
import '../core/i18n.dart';
import '../core/jyotish.dart';
import '../core/location.dart';
import '../core/names.dart';
import '../widgets/city_picker.dart';
import '../widgets/common.dart';
import 'grahanam.dart';
import 'matching.dart' show nakshatraName;

/// Shubha Muhurtham dates for marriage, house warming, buying a vehicle and the naming ceremony, from
/// today to the end of next year, with the good time window of each day for the chosen city.
class ShubhaMuhurthamScreen extends ConsumerStatefulWidget {
  const ShubhaMuhurthamScreen({super.key, this.kind});
  final String? kind;
  @override
  ConsumerState<ShubhaMuhurthamScreen> createState() => _ShubhaMuhurthamScreenState();
}

class _ShubhaMuhurthamScreenState extends ConsumerState<ShubhaMuhurthamScreen> {
  late String _kind = muhurthamKinds.contains(widget.kind) ? widget.kind! : 'vivaha';

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final city = ref.watch(cityProvider);
    final data = ref.watch(muhurthamProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Shubha Muhurtham', 'शुभ मुहूर्त', 'శుభ ముహూర్తాలు'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final k in muhurthamKinds)
                ChoiceChip(
                  label: Text('${muhurthamEmoji(k)} ${muhurthamLabel(lang, k)}'),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ActionChip(
            avatar: const Icon(Icons.location_on_rounded, size: 18),
            label: Text(city.label(lang)),
            onPressed: () => showCityPicker(context, ref),
          ),
          const SizedBox(height: 6),
          Text(_about(lang, _kind), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          ...data.when(
            loading: () => [const SizedBox(height: 420, child: LoadingList(height: 90))],
            error: (e, _) => [ErrorRetry(error: e, onRetry: () => ref.invalidate(muhurthamProvider))],
            data: (all) => _list(lang, all[_kind] ?? const []),
          ),
          const SizedBox(height: 12),
          Text(
            t3(
              lang,
              'These dates pass Panchang Shuddhi. Ask your family priest to match them with the horoscopes '
                  '(Tarabalam, Chandrabalam) and fix the exact lagna.',
              'ये तिथियाँ पंचांग शुद्धि पर खरी हैं। कुंडलियों से मिलान (ताराबल, चंद्रबल) और सटीक लग्न के लिए अपने '
                  'पुरोहित से पूछें।',
              'ఈ తేదీలు పంచాంగ శుద్ధిలో సరిపోయినవి. జాతకాలతో సరిపోల్చడానికి (తారాబలం, చంద్రబలం), ఖచ్చితమైన లగ్నం '
                  'నిర్ణయించడానికి మీ పురోహితుడిని అడగండి.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _about(String lang, String kind) => switch (kind) {
    'vivaha' => t3(
      lang,
      'Sun in a marriage month, outside Chaturmas and Adhika masa, Guru and Shukra not combust; one of the 11 '
          'marriage nakshatras without a bad yoga or karana. Rahu Kalam is left out.',
      'विवाह योग्य सौर मास, चातुर्मास और अधिक मास के बाहर, गुरु-शुक्र अस्त नहीं; 11 विवाह नक्षत्रों में से एक, '
          'अशुभ योग या करण नहीं। राहु काल छोड़ा गया है।',
      'వివాహానికి తగిన సౌర మాసం, చాతుర్మాసం, అధిక మాసం కాకుండా, గురు-శుక్ర మౌఢ్యమి లేకుండా; 11 వివాహ '
          'నక్షత్రాల్లో ఒకటి, చెడు యోగం లేదా కరణం లేకుండా. రాహుకాలం తీసివేశాం.',
    ),
    'griha_pravesha' => t3(
      lang,
      'Magha, Phalguna, Vaishakha, Jyeshtha (or Kartika, Margashirsha); fixed and gentle nakshatras; good tithi '
          'and weekday; Guru and Shukra not combust. Rahu Kalam is left out.',
      'माघ, फाल्गुन, वैशाख, ज्येष्ठ (या कार्तिक, मार्गशीर्ष); स्थिर और मृदु नक्षत्र; शुभ तिथि और वार; गुरु-शुक्र '
          'अस्त नहीं। राहु काल छोड़ा गया है।',
      'మాఘం, ఫాల్గుణం, వైశాఖం, జ్యేష్ఠం (లేదా కార్తీకం, మార్గశిరం); స్థిర, మృదు నక్షత్రాలు; మంచి తిథి, వారం; '
          'గురు-శుక్ర మౌఢ్యమి లేకుండా. రాహుకాలం తీసివేశాం.',
    ),
    'namakarana' => t3(
      lang,
      'Gentle, fixed, swift and movable nakshatras; no Rikta tithi or Amavasya; Sunday, Monday, Wednesday, Thursday '
          'or Friday; not in Adhika masa; a good stretch of at least four hours. Rahu Kalam is left out.',
      'मृदु, ध्रुव, क्षिप्र और चर नक्षत्र; रिक्ता तिथि और अमावस्या नहीं; रवि, सोम, बुध, गुरु या शुक्रवार; अधिक मास '
          'नहीं; कम से कम चार घंटे का शुभ समय। राहु काल छोड़ा गया है।',
      'మృదు, స్థిర, క్షిప్ర, చర నక్షత్రాలు; రిక్త తిథి, అమావాస్య కాకుండా; ఆది, సోమ, బుధ, గురు లేదా శుక్రవారం; '
          'అధిక మాసం కాకుండా; కనీసం నాలుగు గంటల మంచి సమయం. రాహుకాలం తీసివేశాం.',
    ),
    _ => t3(
      lang,
      'Movable, gentle and light nakshatras; good tithi and weekday; not in Pitru Paksha or Adhika masa. Rahu Kalam '
          'is left out.',
      'चर, मृदु और लघु नक्षत्र; शुभ तिथि और वार; पितृ पक्ष और अधिक मास नहीं। राहु काल छोड़ा गया है।',
      'చర, మృదు, లఘు నక్షత్రాలు; మంచి తిథి, వారం; పితృ పక్షం, అధిక మాసం కాకుండా. రాహుకాలం తీసివేశాం.',
    ),
  };

  List<Widget> _list(String lang, List<MuhurthamDay> days) {
    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming = days.where((d) => !d.date.isBefore(today)).toList();
    if (upcoming.isEmpty) {
      return [
        EmptyState(
          icon: Icons.event_busy_rounded,
          title: t3(lang, 'No dates in this period', 'इस अवधि में कोई तिथि नहीं', 'ఈ కాలంలో తేదీలు లేవు'),
        ),
      ];
    }
    final out = <Widget>[];
    int? month;
    for (final d in upcoming) {
      final key = d.date.year * 12 + d.date.month;
      if (key != month) {
        month = key;
        final count = upcoming.where((x) => x.date.year == d.date.year && x.date.month == d.date.month).length;
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
            child: Text(
              '${fmtDate(lang, 'MMMM yyyy', d.date)} · $count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        );
      }
      out.add(_DayCard(day: d, lang: lang));
    }
    return out;
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.lang});
  final MuhurthamDay day;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final d = day;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text('${d.date.day}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
                  Text(fmtDate(lang, 'EEE', d.date), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(windowsText(lang, d), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      d.nakshatras.map((n) => nakshatraName(lang, n)).join(', '),
                      d.tithis.map((t) => tithiName(lang, t)).join(', '),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (d.lagna case (final s, final e, final sign)) ...[
                    const SizedBox(height: 6),
                    Pill(
                      '${t3(lang, 'Best lagna', 'श्रेष्ठ लग्न', 'శ్రేష్ఠ లగ్నం')}: ${signName(lang, sign)} '
                      '${dayClock(lang, d.at(s), d.date)} – ${dayClock(lang, d.at(e), d.date)}',
                      color: Colors.green.shade700,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _tithiNames = [
  'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi', 'Saptami', 'Ashtami', //
  'Navami', 'Dashami', 'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi',
];

/// Tithi 0-29 as "Shukla Panchami", "Purnima", "Amavasya".
String tithiName(String lang, int t) {
  if (t == 14) return tithiIn(lang, 'Purnima');
  if (t == 29) return tithiIn(lang, 'Amavasya');
  return '${pakshaIn(lang, t < 15 ? 'Shukla' : 'Krishna')} ${tithiIn(lang, _tithiNames[t % 15])}';
}
