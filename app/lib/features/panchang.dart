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
    final hi = ref.watch(prefsProvider).language == 'hi';
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
                        DateFormat('EEEE, d MMMM y').format(_day),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(hi ? city.nameHi : city.name, style: Theme.of(context).textTheme.bodySmall),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = data['lunar_month'] as Map;
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
                      child: Text(label(m), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      m['ends'] == null ? '' : 'till ${hhmm('${m['ends']}')}${_nextDay(data, '${m['ends']}')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    Widget span(String key, Map s, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(key, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${hhmm('${s['starts']}')} – ${hhmm('${s['ends']}')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
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
                      '${data['vara']}',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${month['name']} ${month['adhika'] == true ? '(Adhik) ' : ''}· Vikram Samvat ${data['vikram_samvat']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      'Sun in ${data['sun_rashi']} · Moon in ${data['moon_rashi']}',
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
        limb('tithi', data['tithi'] as List, (m) => '${m['paksha']} ${m['name']}'),
        limb('nakshatra', data['nakshatra'] as List, (m) => '${m['name']}'),
        limb('yoga', data['yoga'] as List, (m) => '${m['name']}'),
        limb('karana', data['karana'] as List, (m) => '${m['name']}'),
        const SizedBox(height: 4),
        Text(pick(ref, 'Muhurta', 'मुहूर्त'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            span(tr(ref, 'abhijit'), data['abhijit_muhurta'] as Map, Colors.green),
            const SizedBox(width: 10),
            span('Brahma Muhurta', data['brahma_muhurta'] as Map, Colors.indigo),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            span(tr(ref, 'rahu_kaal'), data['rahu_kaal'] as Map, Colors.red),
            const SizedBox(width: 10),
            span('Yamaganda', data['yamaganda'] as Map, Colors.deepOrange),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            span('Gulika Kaal', data['gulika_kaal'] as Map, Colors.brown),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Computed astronomically (NASA JPL DE421, Lahiri ayanamsa). Regional almanacs may differ by a few minutes.',
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
            tooltip: 'Festival reminders',
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
              if (context.mounted) toast(context, on ? 'Festival reminders on (7 AM)' : 'Festival reminders off');
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
                  DateFormat('MMMM y').format(_month),
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
              for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
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
                          Text(
                            '${d['tithi']}'.substring(0, 3),
                            style: TextStyle(
                              fontSize: 10,
                              color: isSel ? Colors.white70 : Theme.of(context).colorScheme.outline,
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
                  title: Text(pick(ref, f.name, f.nameHi), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: f.description.isEmpty ? null : Text(f.description),
                ),
              ),
          SectionHeader(pick(ref, 'Festivals this month', 'इस माह के त्योहार')),
          if (monthFestivals.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('No major festivals this month.')),
          for (final f in monthFestivals)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${f.date.day}')),
                title: Text(pick(ref, f.name, f.nameHi), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(f.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => setState(() => _selected = f.date),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Dates are computed from the lunar calendar for your city. Local traditions may observe some festivals a day apart.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
