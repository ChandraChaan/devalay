import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/i18n.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

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
                        lang == 'te' ? teluguDate(_day) : DateFormat('EEEE, d MMMM y').format(_day),
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
            child: p.when(
              loading: () => const LoadingList(),
              error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(panchangProvider(_day))),
              data: (d) => _PanchangDetail(data: d),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanchangDetail extends ConsumerWidget {
  const _PanchangDetail({required this.data});
  final Map data;

  static const _uttarayana = {'Makara', 'Kumbha', 'Meena', 'Mesha', 'Vrishabha', 'Mithuna'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider).language;
    final te = lang == 'te';
    final month = data['lunar_month'] as Map;
    final monthIndex = month['index'] as int;
    final tithis = (data['tithi'] as List).cast<Map>();
    final till = t3(lang, 'till', 'तक', 'వరకు');

    String tithiName(Map m) => te
        ? '${teluguPaksha[m['paksha']] ?? ''} ${teluguTithi[m['name']] ?? m['name']}'
        : '${m['paksha']} ${m['name']}';
    String indexed(List<String> names, Map m) => te ? names[m['index'] as int] : '${m['name']}';
    String karana(Map m) => te ? (teluguKarana[m['name']] ?? '${m['name']}') : '${m['name']}';
    String rashi(Object? r) => te ? (teluguRashi['$r'] ?? '$r') : '$r';

    Widget limb(String key, List items, String Function(Map) label) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(ref, key),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
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

    Widget timing(String label, List<Map> spans, Color color, IconData icon) => Container(
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
      _ => [
        '${month['name']} ${adhika ? '(Adhik) ' : ''}· Vikram Samvat ${data['vikram_samvat']}',
        if (samvatsara != null) '${samvatsara['name']} samvatsara · Shaka ${data['shaka_samvat']}',
      ],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GradientCard(
          colors: Palette.sunrise,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      te ? (teluguVara['${data['vara']}'] ?? '${data['vara']}') : '${data['vara']}',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    for (final l in headerLines) Text(l, style: const TextStyle(color: Colors.white)),
                    Text(
                      t3(
                        lang,
                        'Sun in ${data['sun_rashi']} · Moon in ${data['moon_rashi']}',
                        'सूर्य ${data['sun_rashi']} · चंद्र ${data['moon_rashi']}',
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
                ],
              ),
            ],
          ),
        ).animate().fadeIn(),
        const SizedBox(height: 12),
        limb('tithi', tithis, tithiName),
        limb('nakshatra', data['nakshatra'] as List, (m) => indexed(teluguNakshatra, m)),
        limb('yoga', data['yoga'] as List, (m) => indexed(teluguYoga, m)),
        limb('karana', data['karana'] as List, karana),
        const SizedBox(height: 4),
        SectionHeader(t3(lang, 'Good times', 'शुभ समय', 'శుభ సమయాలు')),
        grid([
          timing(tr(ref, 'abhijit'), spansOf('abhijit_muhurta'), Colors.green, Icons.wb_twilight_rounded),
          timing(
            t3(lang, 'Amrit Kalam', 'अमृत काल', 'అమృత కాలం'),
            spansOf('amrit_kalam'),
            Colors.teal,
            Icons.local_florist_rounded,
          ),
          timing(
            t3(lang, 'Brahma Muhurta', 'ब्रह्म मुहूर्त', 'బ్రహ్మ ముహూర్తం'),
            spansOf('brahma_muhurta'),
            Colors.indigo,
            Icons.self_improvement_rounded,
          ),
        ]),
        const SizedBox(height: 12),
        SectionHeader(t3(lang, 'Times to avoid', 'अशुभ समय', 'అశుభ సమయాలు')),
        grid([
          timing(tr(ref, 'rahu_kaal'), spansOf('rahu_kaal'), Colors.red, Icons.block_rounded),
          timing(
            t3(lang, 'Yamaganda', 'यमगंड', 'యమగండం'),
            spansOf('yamaganda'),
            Colors.deepOrange,
            Icons.do_not_disturb_on_rounded,
          ),
          timing(
            t3(lang, 'Durmuhurtham', 'दुर्मुहूर्त', 'దుర్ముహూర్తం'),
            spansOf('durmuhurtham'),
            Colors.pink,
            Icons.timer_off_rounded,
          ),
          timing(
            t3(lang, 'Varjyam', 'वर्ज्यम्', 'వర్జ్యం'),
            spansOf('varjyam'),
            Colors.purple,
            Icons.remove_circle_rounded,
          ),
          timing(
            t3(lang, 'Gulika Kaal', 'गुलिक काल', 'గుళిక కాలం'),
            spansOf('gulika_kaal'),
            Colors.brown,
            Icons.hourglass_bottom_rounded,
          ),
        ]),
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

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(monthProvider((year: _month.year, month: _month.month)));
    final festivals = ref.watch(festivalsProvider(_month.year));
    final prefs = ref.watch(prefsProvider);
    final lang = prefs.language;
    final byDay = <DateTime, List<Festival>>{};
    for (final f in festivals.value ?? const <Festival>[]) {
      byDay.putIfAbsent(f.date, () => []).add(f);
    }
    final selectedFestivals = _selected == null ? const <Festival>[] : (byDay[_selected] ?? const []);
    final monthFestivals = (festivals.value ?? const <Festival>[])
        .where((f) => f.date.month == _month.month && f.major)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'calendar')),
        actions: [
          IconButton(
            tooltip: t3(lang, 'Festival reminders', 'त्योहार रिमाइंडर', 'పండుగ రిమైండర్లు'),
            icon: Icon(prefs.festivalReminders ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
            onPressed: () async {
              final on = !prefs.festivalReminders;
              if (on && !await Notifications.requestPermission()) return;
              await ref.read(prefsProvider.notifier).set('festival_reminders', on);
              if (on) {
                final now = DateTime.now();
                final all = [
                  ...await ref.read(festivalsProvider(now.year).future),
                  if (now.month == 12) ...await ref.read(festivalsProvider(now.year + 1).future),
                ];
                await Notifications.scheduleFestivals(all, lang: prefs.language);
              } else {
                await Notifications.cancelFestivals();
              }
              if (!context.mounted) return;
              toast(
                context,
                on
                    ? t3(
                        lang,
                        'Festival reminders on (7 AM)',
                        'त्योहार रिमाइंडर चालू (सुबह 7 बजे)',
                        'పండుగ రిమైండర్లు ఆన్ (ఉదయం 7)',
                      )
                    : t3(lang, 'Festival reminders off', 'त्योहार रिमाइंडर बंद', 'పండుగ రిమైండర్లు ఆఫ్'),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  lang == 'te'
                      ? '${teluguGregorianMonths[_month.month - 1]} ${_month.year}'
                      : DateFormat('MMMM y').format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (final d
                  in lang == 'te' ? teluguWeekdayShort : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                Expanded(
                  child: Center(child: Text(d, style: Theme.of(context).textTheme.bodySmall)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          days.when(
            loading: () => const SkeletonBox(height: 320),
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(monthProvider((year: _month.year, month: _month.month))),
            ),
            data: (list) {
              final lead = DateTime(_month.year, _month.month, 1).weekday - 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.72,
                ),
                itemCount: lead + list.length,
                itemBuilder: (_, i) {
                  if (i < lead) return const SizedBox.shrink();
                  final d = list[i - lead];
                  final date = DateTime.parse('${d['date']}');
                  final isToday = DateUtils.isSameDay(date, DateTime.now());
                  final isSel = _selected != null && DateUtils.isSameDay(date, _selected);
                  final fest = byDay[date] ?? const [];
                  final major = fest.any((f) => f.major);
                  final tithi = d['tithi_index'] as int;
                  final special = tithi == 15
                      ? '🌕'
                      : tithi == 30
                      ? '🌑'
                      : (tithi == 11 || tithi == 26)
                      ? '🙏'
                      : '';
                  return GestureDetector(
                    onTap: () => setState(() => _selected = date),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSel
                            ? Theme.of(context).colorScheme.primary
                            : (major ? Palette.marigold.withValues(alpha: 0.2) : null),
                        borderRadius: BorderRadius.circular(12),
                        border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isSel ? Colors.white : null,
                            ),
                          ),
                          FittedBox(
                            child: Text(
                              lang == 'te'
                                  ? (teluguTithi['${d['tithi']}'] ?? '${d['tithi']}')
                                  : '${d['tithi']}'.substring(0, 3),
                              style: TextStyle(
                                fontSize: 10,
                                color: isSel ? Colors.white70 : Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                          Text(major ? '🪔' : special, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          if (_selected != null)
            for (final f in selectedFestivals)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(f.major ? '🪔' : '🙏', style: const TextStyle(fontSize: 24)),
                  title: Text(f.label(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: f.description.isEmpty ? null : Text(f.description),
                ),
              ),
          SectionHeader(t3(lang, 'Festivals this month', 'इस माह के त्योहार', 'ఈ నెల పండుగలు')),
          if (monthFestivals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                t3(
                  lang,
                  'No major festivals this month.',
                  'इस माह कोई बड़ा त्योहार नहीं।',
                  'ఈ నెల పెద్ద పండుగలు లేవు.',
                ),
              ),
            ),
          for (final f in monthFestivals)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${f.date.day}')),
                title: Text(f.label(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(f.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => setState(() => _selected = f.date),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            t3(
              lang,
              'Dates are computed from the lunar calendar for your city. Local traditions may observe some festivals a day apart.',
              'तिथियाँ आपके शहर के चंद्र पंचांग से गणना की गई हैं। स्थानीय परंपरा में कुछ पर्व एक दिन आगे-पीछे हो सकते हैं।',
              'తేదీలు మీ నగరపు చాంద్రమాన పంచాంగం ప్రకారం లెక్కించినవి. కొన్ని పండుగలు స్థానిక ఆచారంలో ఒక రోజు తేడాతో ఉండవచ్చు.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
