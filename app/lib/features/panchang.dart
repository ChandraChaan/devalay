import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/glossary.dart';
import '../core/location.dart';
import '../core/names.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'muhurta_view.dart';
import 'personal_day.dart';

class PanchangScreen extends ConsumerStatefulWidget {
  const PanchangScreen({super.key});
  @override
  ConsumerState<PanchangScreen> createState() => _PanchangScreenState();
}

class _PanchangScreenState extends ConsumerState<PanchangScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(panchangProvider(_day));
    final city = ref.watch(cityProvider);
    final lang = ref.watch(prefsProvider).language;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'today_panchang')),
        actions: [
          IconButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(1950),
                lastDate: DateTime(2049, 12, 31),
              );
              if (picked != null) setState(() => _day = picked);
            },
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        fmtDate(lang, 'EEEE, d MMMM y', _day),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(city.label(lang), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _day = _day.add(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            // Swipe left/right to move between days.
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 250) return;
                setState(() => _day = _day.add(Duration(days: v < 0 ? 1 : -1)));
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_day),
                  child: p.when(
                    loading: () => const LoadingList(),
                    error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(panchangProvider(_day))),
                    data: (d) => PanchangDetail(data: d),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PanchangDetail extends ConsumerWidget {
  const PanchangDetail({super.key, required this.data, this.leading = const [], this.padding});
  final Map data;

  /// Widgets shown above the panchang (used by the calendar's day page).
  final List<Widget> leading;
  final EdgeInsets? padding;

  static const _uttarayana = {'Makara', 'Kumbha', 'Meena', 'Mesha', 'Vrishabha', 'Mithuna'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider).language;
    final month = data['lunar_month'] as Map;
    final monthIndex = month['index'] as int;
    final tithis = (data['tithi'] as List).cast<Map>();
    final till = t3(lang, 'till', 'तक', 'వరకు');

    String tithiName(Map m) => lang == 'en'
        ? '${m['paksha']} ${m['name']}'
        : '${pakshaIn(lang, '${m['paksha']}')} ${tithiIn(lang, '${m['name']}')}';
    String karana(Map m) => karanaIn(lang, '${m['name']}');
    String rashi(Object? r) => rashiIn(lang, '$r');

    Widget limb(String key, List items, String Function(Map) label) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tr(ref, key),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                MeaningButton(key, lang: lang),
              ],
            ),
            const SizedBox(height: 6),
            for (final m in items.cast<Map>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label(m), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      m['ends'] == null ? '' : '${hhmm('${m['ends']}')}${_nextDay(data, '${m['ends']}')} $till',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    Widget timing(String label, List<Map> spans, Color color, IconData icon, [String? term]) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: term == null ? null : () => showMeaning(context, lang, term),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.22 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (term != null) Icon(Icons.info_outline_rounded, size: 14, color: color.withValues(alpha: 0.7)),
              ],
            ),
            const SizedBox(height: 4),
            if (spans.isEmpty) Text('—', style: Theme.of(context).textTheme.bodySmall),
            for (final s in spans)
              Text(
                '${hhmm('${s['starts']}')} – ${hhmm('${s['ends']}')}${_nextDay(data, '${s['ends']}')}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
          ],
        ),
      ),
    );

    List<Map> spansOf(String key) {
      final v = data[key];
      if (v is List) return v.cast<Map>();
      if (v is Map) return [v];
      return const [];
    }

    Widget grid(List<Widget> tiles) => LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720 ? 3 : 2;
        final w = (c.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );

    final samvatsara = data['samvatsara'] as Map?;
    final adhika = month['adhika'] == true;
    final sunRashi = '${data['sun_rashi']}';
    final headerLines = switch (lang) {
      'te' => [
        if (samvatsara != null) 'శ్రీ ${teluguSamvatsara[samvatsara['index'] as int]} నామ సంవత్సరం',
        '${adhika ? 'అధిక ' : ''}${teluguMonths[monthIndex]} మాసం · ${teluguPaksha[tithis.first['paksha']] ?? ''}',
        '${_uttarayana.contains(sunRashi) ? 'ఉత్తరాయణం' : 'దక్షిణాయనం'} · ${teluguRitu[monthIndex ~/ 2]} ఋతువు',
      ],
      'hi' => [
        '${month['name']} ${adhika ? '(अधिक) ' : ''}· विक्रम संवत ${data['vikram_samvat']}',
        if (samvatsara != null) '${samvatsara['name']} संवत्सर · शक ${data['shaka_samvat']}',
      ],
      'en' => [
        '${month['name']} ${adhika ? '(Adhik) ' : ''}· Vikram Samvat ${data['vikram_samvat']}',
        if (samvatsara != null) '${samvatsara['name']} samvatsara · Shaka ${data['shaka_samvat']}',
      ],
      _ => [
        if (samvatsara != null)
          '${samvatsaraIn(lang, samvatsara['index'] as int, '${samvatsara['name']}')} ${t3(lang, 'samvatsara', 'संवत्सर', 'నామ సంవత్సరం')}',
        '${adhika ? '${t3(lang, 'Adhika', 'अधिक', 'అధిక')} ' : ''}${monthIn(lang, monthIndex)} ${t3(lang, 'masa', 'मास', 'మాసం')} · ${pakshaIn(lang, '${tithis.first['paksha']}')}',
        '${ayanaIn(lang, _uttarayana.contains(sunRashi))} · ${rituIn(lang, monthIndex ~/ 2)}',
        '${t3(lang, 'Vikram Samvat', 'विक्रम संवत', 'విక్రమ శకం')} ${data['vikram_samvat']} · ${t3(lang, 'Shaka', 'शक', 'శక')} ${data['shaka_samvat']}',
      ],
    };

    return ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        ...leading,
        GradientCard(
          colors: Palette.sunrise,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      varaIn(lang, '${data['vara']}'),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    for (final l in headerLines) Text(l, style: const TextStyle(color: Colors.white)),
                    Text(
                      t3(
                        lang,
                        'Sun in ${lang == 'en' ? data['sun_rashi'] : rashi(data['sun_rashi'])} · Moon in ${lang == 'en' ? data['moon_rashi'] : rashi(data['moon_rashi'])}',
                        'सूर्य ${rashi(data['sun_rashi'])} · चंद्र ${rashi(data['moon_rashi'])}',
                        'సూర్యుడు ${rashi(data['sun_rashi'])} · చంద్రుడు ${rashi(data['moon_rashi'])}',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.wb_sunny_rounded, color: Palette.gold),
                  Text(
                    hhmm('${data['sunrise']}'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.nights_stay_rounded, color: Colors.white70),
                  Text(hhmm('${data['sunset']}'), style: const TextStyle(color: Colors.white)),
                  if (data['moonrise'] != null || data['moonset'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      t3(lang, 'Moon', 'चंद्र', 'చంద్రుడు'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    if (data['moonrise'] != null)
                      Text(
                        '↑ ${hhmm('${data['moonrise']}')}${_nextDay(data, '${data['moonrise']}')}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    if (data['moonset'] != null)
                      Text(
                        '↓ ${hhmm('${data['moonset']}')}${_nextDay(data, '${data['moonset']}')}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ).animate().fadeIn(),
        PersonalBalam(data: data),
        const SizedBox(height: 12),
        limb('tithi', tithis, tithiName),
        limb('nakshatra', data['nakshatra'] as List, (m) => nakshatraIn(lang, '${m['name']}')),
        limb('yoga', data['yoga'] as List, (m) => yogaIn(lang, '${m['name']}', m['index'] as int)),
        limb('karana', data['karana'] as List, karana),
        const SizedBox(height: 4),
        SectionHeader(t3(lang, 'Good times', 'शुभ समय', 'శుభ సమయాలు')),
        grid([
          timing(tr(ref, 'abhijit'), spansOf('abhijit_muhurta'), Colors.green, Icons.wb_twilight_rounded, 'abhijit'),
          timing(
            t3(lang, 'Amrit Kalam', 'अमृत काल', 'అమృత కాలం'),
            spansOf('amrit_kalam'),
            Colors.teal,
            Icons.local_florist_rounded,
            'amrit',
          ),
          timing(
            t3(lang, 'Brahma Muhurta', 'ब्रह्म मुहूर्त', 'బ్రహ్మ ముహూర్తం'),
            spansOf('brahma_muhurta'),
            Colors.indigo,
            Icons.self_improvement_rounded,
            'brahma',
          ),
        ]),
        const SizedBox(height: 12),
        SectionHeader(t3(lang, 'Times to avoid', 'अशुभ समय', 'అశుభ సమయాలు')),
        grid([
          timing(tr(ref, 'rahu_kaal'), spansOf('rahu_kaal'), Colors.red, Icons.block_rounded, 'rahu'),
          timing(
            t3(lang, 'Yamaganda', 'यमगंड', 'యమగండం'),
            spansOf('yamaganda'),
            Colors.deepOrange,
            Icons.do_not_disturb_on_rounded,
            'yama',
          ),
          timing(
            t3(lang, 'Durmuhurtham', 'दुर्मुहूर्त', 'దుర్ముహూర్తం'),
            spansOf('durmuhurtham'),
            Colors.pink,
            Icons.timer_off_rounded,
            'durmuhurtham',
          ),
          timing(
            t3(lang, 'Varjyam', 'वर्ज्यम्', 'వర్జ్యం'),
            spansOf('varjyam'),
            Colors.purple,
            Icons.remove_circle_rounded,
            'varjyam',
          ),
          timing(
            t3(lang, 'Gulika Kaal', 'गुलिक काल', 'గుళిక కాలం'),
            spansOf('gulika_kaal'),
            Colors.brown,
            Icons.hourglass_bottom_rounded,
            'gulika',
          ),
        ]),
        MuhurtaTimings(data: data),
        const SizedBox(height: 16),
        Text(
          t3(
            lang,
            'Computed astronomically (NASA JPL DE421, Lahiri ayanamsa). Regional almanacs may differ by a few minutes.',
            'खगोलीय गणना (NASA JPL DE421, लाहिरी अयनांश)। स्थानीय पंचांगों में कुछ मिनट का अंतर हो सकता है।',
            'ఖగోళ గణన ఆధారంగా (NASA JPL DE421, లాహిరి అయనాంశ). స్థానిక పంచాంగాలతో కొన్ని నిమిషాల తేడా ఉండవచ్చు.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _nextDay(Map data, String iso) => iso.substring(0, 10) != '${data['date']}' ? ' (+1)' : '';
}
