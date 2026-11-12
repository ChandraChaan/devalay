import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../core/wishes.dart';
import '../widgets/common.dart';
import 'panchang.dart';

// The calendar covers 1950–2049, the range the panchang is computed for.
final _firstMonth = DateTime(1950);
const _monthCount = 100 * 12;
final _firstDay = DateTime(1950);
final _lastDay = DateTime(2049, 12, 31);

int _monthIndex(DateTime m) => (m.year - _firstMonth.year) * 12 + m.month - 1;
DateTime _monthAt(int i) => DateTime(_firstMonth.year, i + 1);
int _dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1950)).inDays;
DateTime _dayAt(int i) => DateTime(_firstDay.year, 1, 1 + i);
String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

const _nakshatraNames = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra', 'Punarvasu', 'Pushya', 'Ashlesha', //
  'Magha', 'Purva Phalguni', 'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha',
  'Jyeshtha', 'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana', 'Dhanishta', 'Shatabhisha',
  'Purva Bhadrapada', 'Uttara Bhadrapada', 'Revati',
];

/// Sunday first, as printed Indian calendars do.
List<String> _weekdayLabels(String lang) => switch (lang) {
  'te' => ['ఆది', 'సోమ', 'మంగళ', 'బుధ', 'గురు', 'శుక్ర', 'శని'],
  'hi' => ['रवि', 'सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि'],
  _ => ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
};

String _monthTitle(String lang, DateTime m) =>
    lang == 'te' ? '${teluguGregorianMonths[m.month - 1]} ${m.year}' : DateFormat('MMMM y').format(m);

String _tithiLabel(String lang, Map d) =>
    lang == 'te' ? (teluguTithi['${d['tithi']}'] ?? '${d['tithi']}') : '${d['tithi']}';

String _pakshaLabel(String lang, Map d) =>
    lang == 'te' ? (teluguPaksha['${d['paksha']}'] ?? '${d['paksha']}') : '${d['paksha']} paksha';

String _nakshatraLabel(String lang, Map d) {
  final name = '${d['nakshatra']}';
  if (lang != 'te') return name;
  final i = _nakshatraNames.indexOf(name);
  return i < 0 ? name : teluguNakshatra[i + 1];
}

/// 🌕 Purnima, 🌑 Amavasya, 🙏 Ekadashi, else empty.
String _moonMark(Map d) => switch (d['tithi_index'] as int? ?? 0) {
  15 => '🌕',
  30 => '🌑',
  11 || 26 => '🙏',
  _ => '',
};

Map<DateTime, List<Festival>> _festivalsByDay(List<Festival>? list) {
  final out = <DateTime, List<Festival>>{};
  for (final f in list ?? const <Festival>[]) {
    out.putIfAbsent(DateUtils.dateOnly(f.date), () => []).add(f);
  }
  for (final l in out.values) {
    l.sort((a, b) => (b.major ? 1 : 0) - (a.major ? 1 : 0));
  }
  return out;
}

String _countdown(String lang, int days) => switch (days) {
  0 => t3(lang, 'Today', 'आज', 'ఈరోజు'),
  1 => t3(lang, 'Tomorrow', 'कल', 'రేపు'),
  -1 => t3(lang, 'Yesterday', 'कल था', 'నిన్న'),
  > 1 => t3(lang, 'in $days days', '$days दिन में', '$days రోజుల్లో'),
  _ => t3(lang, '${-days} days ago', '${-days} दिन पहले', '${-days} రోజుల క్రితం'),
};

// ---------------------------------------------------------------------------
// Month calendar
// ---------------------------------------------------------------------------

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final _thisMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late final PageController _pages = PageController(initialPage: _monthIndex(_thisMonth));
  late DateTime _month = _thisMonth;
  DateTime _selected = DateUtils.dateOnly(DateTime.now());
  bool _full = false;

  @override
  void dispose() {
    if (_full) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pages.dispose();
    super.dispose();
  }

  void _goToMonth(DateTime m, {bool animate = true}) {
    final i = _monthIndex(m).clamp(0, _monthCount - 1);
    if (animate && (i - (_pages.page ?? i)).abs() <= 2) {
      _pages.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _pages.jumpToPage(i);
    }
  }

  void _today() {
    setState(() => _selected = DateUtils.dateOnly(DateTime.now()));
    _goToMonth(_thisMonth);
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected.month == _month.month && _selected.year == _month.year ? _selected : _month,
      firstDate: _firstDay,
      lastDate: _lastDay,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    setState(() => _selected = picked);
    _goToMonth(DateTime(picked.year, picked.month), animate: false);
  }

  void _setFull(bool on) {
    HapticFeedback.selectionClick();
    setState(() => _full = on);
    SystemChrome.setEnabledSystemUIMode(on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  void _onDayTap(DateTime date) {
    HapticFeedback.selectionClick();
    if (_full || DateUtils.isSameDay(date, _selected)) {
      setState(() => _selected = date);
      context.push('/calendar/day/${_iso(date)}');
      return;
    }
    setState(() => _selected = date);
    if (date.month != _month.month) _goToMonth(DateTime(date.year, date.month));
  }

  Future<void> _toggleReminders() async {
    final prefs = ref.read(prefsProvider);
    final lang = prefs.language;
    final on = !prefs.festivalReminders;
    if (on && !await Notifications.requestPermission()) return;
    await ref.read(prefsProvider.notifier).set('festival_reminders', on);
    if (on) {
      final now = DateTime.now();
      final all = [
        ...await ref.read(festivalsProvider(now.year).future),
        if (now.month == 12) ...await ref.read(festivalsProvider(now.year + 1).future),
      ];
      await Notifications.scheduleFestivals(all, lang: lang);
    } else {
      await Notifications.cancelFestivals();
    }
    if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final lang = prefs.language;
    final isThisMonth = _month == _thisMonth;

    final header = _MonthHeader(
      month: _month,
      lang: lang,
      onPrev: () => _pages.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
      onNext: () => _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
      onTitle: _pickMonth,
    );

    Widget pager({required bool full}) => PageView.builder(
      controller: _pages,
      itemCount: _monthCount,
      onPageChanged: (i) => setState(() => _month = _monthAt(i)),
      itemBuilder: (_, i) => _MonthGrid(month: _monthAt(i), selected: _selected, full: full, onTap: _onDayTap),
    );

    if (_full) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _setFull(false);
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: t3(lang, 'Exit full screen', 'पूर्ण स्क्रीन बंद', 'పూర్తి స్క్రీన్ మూసివేయి'),
                      onPressed: () => _setFull(false),
                      icon: const Icon(Icons.fullscreen_exit_rounded),
                    ),
                    Expanded(child: header),
                    IconButton(
                      tooltip: t3(lang, 'Today', 'आज', 'ఈరోజు'),
                      onPressed: isThisMonth ? null : _today,
                      icon: const Icon(Icons.today_rounded),
                    ),
                  ],
                ),
                _WeekdayRow(lang: lang),
                Expanded(child: pager(full: true)),
                const _Legend(),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'calendar')),
        actions: [
          if (!isThisMonth)
            TextButton.icon(
              onPressed: _today,
              icon: const Icon(Icons.today_rounded, size: 18),
              label: Text(t3(lang, 'Today', 'आज', 'ఈరోజు')),
            ),
          IconButton(
            tooltip: t3(lang, 'Full screen', 'पूर्ण स्क्रीन', 'పూర్తి స్క్రీన్'),
            onPressed: () => _setFull(true),
            icon: const Icon(Icons.fullscreen_rounded),
          ),
          IconButton(
            tooltip: t3(lang, 'Festival reminders', 'त्योहार रिमाइंडर', 'పండుగ రిమైండర్లు'),
            icon: Icon(prefs.festivalReminders ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
            onPressed: _toggleReminders,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          // Size cells from the width, but never let the grid take more than
          // ~60% of the screen so the day card stays in view.
          final width = box.maxWidth.clamp(0, Breakpoints.content).toDouble() - 16;
          final cellH = (width / 7 / 0.82).clamp(54.0, math.max(54.0, box.maxHeight * 0.6 / 6));
          final rows = _rowsFor(_month);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Breakpoints.content),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: header),
                  SliverToBoxAdapter(child: _WeekdayRow(lang: lang)),
                  SliverToBoxAdapter(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      height: rows * cellH + 8,
                      child: ClipRect(child: pager(full: false)),
                    ),
                  ),
                  const SliverToBoxAdapter(child: _Legend()),
                  SliverToBoxAdapter(
                    child: _SelectedDayCard(
                      date: _selected,
                      onOpen: () => context.push('/calendar/day/${_iso(_selected)}'),
                    ),
                  ),
                  _MonthFestivals(month: _month, onTap: (d) => setState(() => _selected = d)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: Text(
                        t3(
                          lang,
                          'Dates are computed from the lunar calendar for your city. Local traditions may observe some festivals a day apart.',
                          'तिथियाँ आपके शहर के चंद्र पंचांग से गणना की गई हैं। स्थानीय परंपरा में कुछ पर्व एक दिन आगे-पीछे हो सकते हैं।',
                          'తేదీలు మీ నగరపు చాంద్రమాన పంచాంగం ప్రకారం లెక్కించినవి. కొన్ని పండుగలు స్థానిక ఆచారంలో ఒక రోజు తేడాతో ఉండవచ్చు.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

int _rowsFor(DateTime month) {
  final lead = DateTime(month.year, month.month, 1).weekday % 7;
  final days = DateUtils.getDaysInMonth(month.year, month.month);
  return ((lead + days) / 7).ceil();
}

class _MonthHeader extends ConsumerWidget {
  const _MonthHeader({
    required this.month,
    required this.lang,
    required this.onPrev,
    required this.onNext,
    required this.onTitle,
  });
  final DateTime month;
  final String lang;
  final VoidCallback onPrev, onNext, onTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final festivals = ref.watch(festivalsProvider(month.year)).value ?? const <Festival>[];
    final inMonth = festivals.where((f) => f.date.month == month.month).toList();
    final major = inMonth.where((f) => f.major).length;
    final city = ref.watch(cityProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTitle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        key: ValueKey(month),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _monthTitle(lang, month),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded),
                        ],
                      ),
                    ),
                    Text(
                      [
                        city.label(lang),
                        if (major > 0) t3(lang, '$major festivals', '$major त्योहार', '$major పండుగలు'),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.lang});
  final String lang;
  @override
  Widget build(BuildContext context) {
    final labels = _weekdayLabels(lang);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  labels[i],
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: i == 0 ? Palette.vermilion : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.month, required this.selected, required this.full, required this.onTap});
  final DateTime month;
  final DateTime selected;
  final bool full;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(monthProvider((year: month.year, month: month.month)));
    final byDay = _festivalsByDay(ref.watch(festivalsProvider(month.year)).value);
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final lead = DateTime(month.year, month.month, 1).weekday % 7;
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = _rowsFor(month);
    final summary = <int, Map>{for (final d in days.value ?? const <Map>[]) DateTime.parse('${d['date']}').day: d};

    if (days.hasError && summary.isEmpty) {
      return ErrorRetry(
        error: days.error!,
        onRetry: () => ref.invalidate(monthProvider((year: month.year, month: month.month))),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final cellH = (box.maxHeight - 8) / rows;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Column(
            children: [
              for (var r = 0; r < rows; r++)
                SizedBox(
                  height: cellH,
                  child: Row(
                    children: [
                      for (var c = 0; c < 7; c++)
                        Expanded(
                          child: Builder(
                            builder: (_) {
                              final n = r * 7 + c - lead + 1;
                              if (n < 1 || n > count) return const SizedBox.shrink();
                              final date = DateTime(month.year, month.month, n);
                              return _DayCell(
                                date: date,
                                info: summary[n],
                                festivals: byDay[date] ?? const [],
                                selected: DateUtils.isSameDay(date, selected),
                                full: full,
                                lang: lang,
                                onTap: () => onTap(date),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.info,
    required this.festivals,
    required this.selected,
    required this.full,
    required this.lang,
    required this.onTap,
  });
  final DateTime date;
  final Map? info;
  final List<Festival> festivals;
  final bool selected, full;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateUtils.isSameDay(date, DateTime.now());
    final major = festivals.any((f) => f.major);
    final sunday = date.weekday == DateTime.sunday;
    final fg = selected ? Colors.white : (sunday || major ? Palette.vermilion : scheme.onSurface);
    final sub = selected ? Colors.white70 : scheme.outline;
    final mark = info == null ? '' : _moonMark(info!);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: () => context.push('/calendar/day/${_iso(date)}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(colors: Palette.sunrise) : null,
              color: selected
                  ? null
                  : major
                  ? Palette.marigold.withValues(alpha: context.isDark ? 0.22 : 0.16)
                  : (full ? scheme.surfaceContainerLow : null),
              borderRadius: BorderRadius.circular(12),
              border: today && !selected ? Border.all(color: scheme.primary, width: 2) : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Palette.saffron.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            padding: EdgeInsets.symmetric(horizontal: full ? 2 : 3, vertical: full ? 4 : 2),
            child: full ? _fullBody(context, fg, sub, mark) : _compactBody(fg, sub, mark),
          ),
        ),
      ),
    );
  }

  Widget _compactBody(Color fg, Color sub, String mark) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        '${date.day}',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: fg, height: 1.1),
      ),
      if (info != null)
        FittedBox(
          child: Text(
            lang == 'te' ? _tithiLabel(lang, info!) : _tithiLabel(lang, info!).substring(0, 3),
            style: TextStyle(fontSize: 10, color: sub),
          ),
        ),
      SizedBox(
        height: 14,
        child: festivals.isNotEmpty
            ? Text(festivals.any((f) => f.major) ? '🪔' : '•', style: TextStyle(fontSize: 11, color: fg))
            : Text(mark, style: const TextStyle(fontSize: 10)),
      ),
    ],
  );

  Widget _fullBody(BuildContext context, Color fg, Color sub, String mark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${date.day}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: fg, height: 1.1),
            ),
            const Spacer(),
            if (mark.isNotEmpty) Text(mark, style: const TextStyle(fontSize: 11)),
          ],
        ),
        if (info != null)
          Text(
            _tithiLabel(lang, info!),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(fontSize: 10, color: sub, height: 1.2),
          ),
        const SizedBox(height: 2),
        Expanded(
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in festivals)
                  Text(
                    f.label(lang),
                    maxLines: f.major ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.15,
                      letterSpacing: -0.1,
                      fontWeight: f.major ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : (f.major ? Palette.saffron : sub),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends ConsumerWidget {
  const _Legend();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final style = Theme.of(context).textTheme.bodySmall;
    Widget item(String mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(mark, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 4,
        children: [
          item('🪔', t3(lang, 'Festival', 'त्योहार', 'పండుగ')),
          item('🌕', t3(lang, 'Purnima', 'पूर्णिमा', 'పౌర్ణమి')),
          item('🌑', t3(lang, 'Amavasya', 'अमावस्या', 'అమావాస్య')),
          item('🙏', t3(lang, 'Ekadashi', 'एकादशी', 'ఏకాదశి')),
        ],
      ),
    );
  }
}

class _SelectedDayCard extends ConsumerWidget {
  const _SelectedDayCard({required this.date, required this.onOpen});
  final DateTime date;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final days = ref.watch(monthProvider((year: date.year, month: date.month))).value ?? const <Map>[];
    final info = days.where((d) => d['date'] == _iso(date)).firstOrNull;
    final festivals = _festivalsByDay(ref.watch(festivalsProvider(date.year)).value)[date] ?? const <Festival>[];
    final major = festivals.any((f) => f.major);
    final away = date.difference(DateUtils.dateOnly(DateTime.now())).inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: GradientCard(
        colors: major ? Palette.sunrise : const [Color(0xFF5D1A0B), Color(0xFF8D2B0B), Color(0xFFBF5B04)],
        padding: 16,
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Text(
                      '${date.day}',
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1),
                    ),
                    Text(
                      lang == 'te'
                          ? teluguGregorianMonths[date.month - 1]
                          : DateFormat('MMM').format(date).toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lang == 'te' ? teluguWeekdays[date.weekday - 1] : DateFormat('EEEE').format(date),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _countdown(lang, away),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (info != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_pakshaLabel(lang, info)} · ${_tithiLabel(lang, info)} ${_moonMark(info)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          '${tr(ref, 'nakshatra')}: ${_nakshatraLabel(lang, info)} · ☀ ${hhmm('${info['sunrise']}')}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (festivals.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in festivals)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: f.major ? 0.25 : 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${f.major ? '🪔 ' : ''}${f.label(lang)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  t3(lang, 'Full panchang & details', 'पूरा पंचांग व विवरण', 'పూర్తి పంచాంగం & వివరాలు'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
              ],
            ),
          ],
        ),
      ).animate(key: ValueKey(date)).fadeIn(duration: 250.ms).slideY(begin: 0.04),
    );
  }
}

class _MonthFestivals extends ConsumerWidget {
  const _MonthFestivals({required this.month, required this.onTap});
  final DateTime month;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final all = (ref.watch(festivalsProvider(month.year)).value ?? const <Festival>[])
        .where((f) => f.date.month == month.month)
        .toList();
    final major = all.where((f) => f.major).toList();
    final vrats = all.where((f) => !f.major).toList();
    final today = DateTime.now();

    Widget tile(Festival f) {
      final away = f.daysFrom(today);
      final past = away < 0;
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ListTile(
          onTap: () => onTap(DateUtils.dateOnly(f.date)),
          onLongPress: () => context.push('/calendar/day/${_iso(f.date)}'),
          leading: Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              gradient: f.major && !past ? const LinearGradient(colors: Palette.sunrise) : null,
              color: f.major && !past ? null : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${f.date.day}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: f.major && !past ? Colors.white : null,
                  ),
                ),
                Text(
                  _weekdayLabels(lang)[f.date.weekday % 7],
                  style: TextStyle(fontSize: 10, color: f.major && !past ? Colors.white70 : null),
                ),
              ],
            ),
          ),
          title: Text(
            f.label(lang),
            style: TextStyle(fontWeight: FontWeight.w700, color: past ? Theme.of(context).colorScheme.outline : null),
          ),
          subtitle: f.description.isEmpty ? null : Text(f.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: away >= 0 && away <= 60
              ? Text(
                  _countdown(lang, away),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
        ),
      );
    }

    return SliverList.list(
      children: [
        SectionHeader(t3(lang, 'Festivals this month', 'इस माह के त्योहार', 'ఈ నెల పండుగలు')),
        if (major.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              t3(lang, 'No major festivals this month.', 'इस माह कोई बड़ा त्योहार नहीं।', 'ఈ నెల పెద్ద పండుగలు లేవు.'),
            ),
          ),
        for (final f in major) tile(f),
        if (vrats.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(
                t3(
                  lang,
                  'Vrats & observances (${vrats.length})',
                  'व्रत व पर्व (${vrats.length})',
                  'వ్రతాలు & పర్వదినాలు (${vrats.length})',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              children: [for (final f in vrats) tile(f)],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen day page
// ---------------------------------------------------------------------------

class CalendarDayScreen extends ConsumerStatefulWidget {
  const CalendarDayScreen({super.key, required this.date});
  final DateTime date;
  @override
  ConsumerState<CalendarDayScreen> createState() => _CalendarDayScreenState();
}

class _CalendarDayScreenState extends ConsumerState<CalendarDayScreen> {
  late final _pages = PageController(initialPage: _dayIndex(widget.date));
  late DateTime _day = DateUtils.dateOnly(widget.date);
  final _total = _dayIndex(_lastDay) + 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _share() {
    final lang = ref.read(prefsProvider).language;
    final p = ref.read(panchangProvider(_day)).value;
    final fest = _festivalsByDay(ref.read(festivalsProvider(_day.year)).value)[_day] ?? const <Festival>[];
    final lines = <String>[
      '🗓️ ${lang == 'te' ? teluguDate(_day) : DateFormat('EEEE, d MMMM y').format(_day)}',
      for (final f in fest) '🪔 ${f.label(lang)}',
      if (p != null) ...[
        '${tr(ref, 'tithi')}: ${((p['tithi'] as List).first as Map)['paksha']} ${((p['tithi'] as List).first as Map)['name']}',
        '${tr(ref, 'nakshatra')}: ${((p['nakshatra'] as List).first as Map)['name']}',
        '☀ ${hhmm('${p['sunrise']}')}  🌙 ${hhmm('${p['sunset']}')}',
        if (p['rahu_kaal'] is Map)
          '${tr(ref, 'rahu_kaal')}: ${hhmm('${(p['rahu_kaal'] as Map)['starts']}')} – ${hhmm('${(p['rahu_kaal'] as Map)['ends']}')}',
      ],
      '',
      '— Devalay',
    ];
    SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final today = DateUtils.dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang == 'te'
              ? '${_day.day} ${teluguGregorianMonths[_day.month - 1]} ${_day.year}'
              : DateFormat('d MMM y').format(_day),
        ),
        actions: [
          if (!DateUtils.isSameDay(_day, today))
            IconButton(
              tooltip: t3(lang, 'Today', 'आज', 'ఈరోజు'),
              onPressed: () => _pages.jumpToPage(_dayIndex(today)),
              icon: const Icon(Icons.today_rounded),
            ),
          IconButton(
            tooltip: t3(lang, 'Pick a date', 'तारीख चुनें', 'తేదీ ఎంచుకోండి'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: _firstDay,
                lastDate: _lastDay,
              );
              if (picked != null) _pages.jumpToPage(_dayIndex(picked));
            },
            icon: const Icon(Icons.edit_calendar_rounded),
          ),
          IconButton(tooltip: 'Share', onPressed: _share, icon: const Icon(Icons.share_rounded)),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: _total,
            onPageChanged: (i) => setState(() => _day = _dayAt(i)),
            itemBuilder: (_, i) => _DayPage(day: _dayAt(i)),
          ),
          // Prev / next day nudges for people who don't discover swiping.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    _NudgeButton(
                      icon: Icons.chevron_left_rounded,
                      label: _shortDay(lang, _day.subtract(const Duration(days: 1))),
                      onTap: () =>
                          _pages.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    ),
                    const Spacer(),
                    _NudgeButton(
                      icon: Icons.chevron_right_rounded,
                      label: _shortDay(lang, _day.add(const Duration(days: 1))),
                      trailing: true,
                      onTap: () => _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDay(String lang, DateTime d) =>
      lang == 'te' ? '${d.day} ${teluguGregorianMonths[d.month - 1]}' : DateFormat('d MMM').format(d);
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.icon, required this.label, required this.onTap, this.trailing = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool trailing;
  @override
  Widget build(BuildContext context) {
    final children = [Icon(icon, size: 20), Text(label, style: const TextStyle(fontWeight: FontWeight.w600))];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: trailing ? children.reversed.toList() : children),
        ),
      ),
    );
  }
}

class _DayPage extends ConsumerWidget {
  const _DayPage({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final festivals = _festivalsByDay(ref.watch(festivalsProvider(day.year)).value)[day] ?? const <Festival>[];
    final panchang = ref.watch(panchangProvider(day));
    final major = festivals.any((f) => f.major);
    final away = day.difference(DateUtils.dateOnly(DateTime.now())).inDays;
    final wishes = ref.watch(wishCatalogProvider).value;

    final hero = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: major ? Palette.sunrise : Palette.dusk,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Text(
            '${day.day}',
            style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800, height: 1),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'te' ? teluguWeekdays[day.weekday - 1] : DateFormat('EEEE').format(day),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                Text(_monthTitle(lang, day), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _countdown(lang, away),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);

    final festivalCards = [
      for (final f in festivals)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.major ? '🪔' : '🙏', style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.label(lang),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (f.deity.isNotEmpty)
                        Text(
                          f.deity[0].toUpperCase() + f.deity.substring(1),
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      if (f.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(f.description, style: const TextStyle(height: 1.5)),
                      ],
                      if (wishes?.forFestival(f) case final w?)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            onPressed: () => context.push('/wishes/${w.id}'),
                            icon: const Icon(Icons.card_giftcard_rounded),
                            label: Text(t3(lang, 'Send wishes', 'शुभकामनाएँ भेजें', 'శుభాకాంక్షలు పంపండి')),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
    const pad = EdgeInsets.fromLTRB(16, 8, 16, 80);

    return panchang.when(
      data: (d) => PanchangDetail(data: d, leading: [hero, ...festivalCards], padding: pad),
      loading: () => ListView(
        padding: pad,
        children: [
          hero,
          ...festivalCards,
          const SkeletonBox(height: 110),
          const SizedBox(height: 10),
          const SkeletonBox(height: 260),
        ],
      ),
      error: (e, _) => ListView(
        padding: pad,
        children: [
          hero,
          ...festivalCards,
          _MonthSummary(day: day),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    t3(
                      lang,
                      'The full panchang for this date isn\'t available offline yet. Dates within a few weeks of today work best.',
                      'इस तारीख का पूरा पंचांग अभी उपलब्ध नहीं है। आज के आसपास की तारीखें देखें।',
                      'ఈ తేదీకి పూర్తి పంచాంగం ఇంకా అందుబాటులో లేదు. ఈరోజుకు దగ్గరి తేదీలు చూడండి.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(panchangProvider(day)),
                    child: Text(t3(lang, 'Try again', 'फिर कोशिश करें', 'మళ్ళీ ప్రయత్నించండి')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tithi / nakshatra / sunrise from the month summary, for dates whose full
/// panchang is not available.
class _MonthSummary extends ConsumerWidget {
  const _MonthSummary({required this.day});
  final DateTime day;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final days = ref.watch(monthProvider((year: day.year, month: day.month))).value ?? const <Map>[];
    final info = days.where((d) => d['date'] == _iso(day)).firstOrNull;
    if (info == null) return const SizedBox.shrink();
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row(tr(ref, 'tithi'), '${_tithiLabel(lang, info)} ${_moonMark(info)}'),
            row(t3(lang, 'Paksha', 'पक्ष', 'పక్షం'), _pakshaLabel(lang, info)),
            row(tr(ref, 'nakshatra'), _nakshatraLabel(lang, info)),
            row(t3(lang, 'Sunrise', 'सूर्योदय', 'సూర్యోదయం'), hhmm('${info['sunrise']}')),
          ],
        ),
      ),
    );
  }
}
