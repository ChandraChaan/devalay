import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/calendar_reminders.dart';
import '../core/events.dart';
import '../core/i18n.dart';
import '../core/muhurta.dart';
import '../core/notifications.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

String _fmtDate(String lang, DateTime d) =>
    lang == 'te' ? '${d.day} ${teluguGregorianMonths[d.month - 1]} ${d.year}' : DateFormat('EEE, d MMM y').format(d);

String _repeatLabel(String lang, UserEvent e) => switch (e.repeat) {
  EventRepeat.once => t3(lang, 'Once', 'एक बार', 'ఒక్కసారి'),
  EventRepeat.yearly => t3(lang, 'Every year on this date', 'हर साल इसी तारीख', 'ప్రతి సంవత్సరం ఇదే తేదీన'),
  EventRepeat.tithi =>
    '${t3(lang, 'Every year by tithi', 'हर साल तिथि अनुसार', 'ప్రతి సంవత్సరం తిథి ప్రకారం')}: ${e.tithiLabel(lang)}',
};

/// Adds a personal event, or edits [existing].
Future<void> showEventEditor(
  BuildContext context,
  WidgetRef ref, {
  DateTime? date,
  UserEvent? existing,
  String? kind,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _EventEditor(date: date ?? DateTime.now(), existing: existing, kind: kind),
);

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({required this.date, this.existing, this.kind});
  final DateTime date;
  final UserEvent? existing;
  final String? kind;
  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late String _kind = widget.existing?.kind ?? widget.kind ?? 'birthday';
  late DateTime _date = DateUtils.dateOnly(widget.existing?.date ?? widget.date);
  late EventRepeat _repeat = widget.existing?.repeat ?? _defaultRepeat(_kind);
  late int? _month = widget.existing?.lunarMonth;
  late int? _tithi = widget.existing?.tithi;
  late bool _remind = widget.existing?.remind ?? true;
  bool _repeatTouched = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repeatTouched = widget.existing != null;
    if (_tithi == null) _readTithi();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// Fills the tithi and lunar month from the chosen date's panchang, when the phone has it.
  Future<void> _readTithi() async {
    final d = _date;
    try {
      final days = await ref.read(monthProvider((year: d.year, month: d.month)).future);
      final s = days.where((x) => x['date'] == DateFormat('yyyy-MM-dd').format(d)).firstOrNull;
      if (!mounted || s == null || s['lunar_month'] == null || d != _date) return;
      setState(() {
        _tithi = s['tithi_index'] as int;
        _month = s['lunar_month'] as int;
      });
    } catch (_) {
      // Not available offline: the user picks the tithi by hand.
    }
  }

  static EventRepeat _defaultRepeat(String kind) => switch (kind) {
    'remembrance' => EventRepeat.tithi,
    'birthday' || 'anniversary' => EventRepeat.yearly,
    _ => EventRepeat.once,
  };

  void _setKind(String k) {
    setState(() {
      _kind = k;
      if (!_repeatTouched) _repeat = _defaultRepeat(k);
    });
  }

  /// The next date with the current choices, when the phone has the panchang to work it out.
  DateTime? _preview() {
    if (_repeat == EventRepeat.tithi && (_tithi == null || _month == null)) return null;
    final now = DateTime.now();
    final draft = UserEvent(
      id: '',
      title: '',
      kind: _kind,
      date: _date,
      repeat: _repeat,
      tithi: _tithi,
      lunarMonth: _month,
    );
    if (_repeat != EventRepeat.tithi) return nextOccurrence(draft, now, const [], const []);
    final a = ref.watch(yearDaysProvider(now.year)).value;
    final b = ref.watch(yearDaysProvider(now.year + 1)).value;
    if (a == null) return null;
    return nextOccurrence(draft, now, a, b ?? const []);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8, left: 2),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2049, 12, 31),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _readTithi();
  }

  Future<void> _save() async {
    final lang = ref.read(prefsProvider).language;
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, t3(lang, 'Please enter a name', 'कृपया नाम लिखें', 'దయచేసి పేరు రాయండి'));
      return;
    }
    if (_repeat == EventRepeat.tithi && (_tithi == null || _month == null)) {
      toast(context, t3(lang, 'Please choose the tithi', 'कृपया तिथि चुनें', 'దయచేసి తిథి ఎంచుకోండి'));
      return;
    }
    setState(() => _saving = true);
    if (_remind) await Notifications.requestPermission();
    final e = UserEvent(
      id: widget.existing?.id ?? EventsNotifier.newId(),
      title: title,
      kind: _kind,
      date: _date,
      repeat: _repeat,
      tithi: _repeat == EventRepeat.tithi ? _tithi : null,
      lunarMonth: _repeat == EventRepeat.tithi ? _month : null,
      remind: _remind,
    );
    await ref.read(eventsProvider.notifier).save(e);
    final now = DateTime.now();
    final tithi = e.repeat == EventRepeat.tithi;
    Future<List<Map>> days(int y) => ref.read(yearDaysProvider(y).future).catchError((Object _) => <Map>[]);
    final thisYear = tithi ? await days(now.year) : const <Map>[];
    final nextYear = tithi ? await days(now.year + 1) : const <Map>[];
    await scheduleEventReminder(e, lang, thisYear: thisYear, nextYear: nextYear);
    if (ref.read(prefsProvider).panchangDaily) await refreshPanchangNotifications(ref);
    if (!mounted) return;
    final next = nextOccurrence(e, now, thisYear, nextYear);
    Navigator.of(context).pop();
    toast(
      context,
      next == null
          ? t3(lang, 'Saved', 'सहेजा गया', 'సేవ్ అయింది')
          : '${t3(lang, 'Saved. Next', 'सहेजा गया। अगली बार', 'సేవ్ అయింది. తదుపరి')}: ${_fmtDate(lang, next)}',
    );
  }

  Future<void> _delete() async {
    final lang = ref.read(prefsProvider).language;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t3(lang, 'Delete this event?', 'यह दिन हटाएँ?', 'ఈ రోజును తొలగించాలా?')),
        content: Text(widget.existing!.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t3(lang, 'Cancel', 'रद्द करें', 'రద్దు'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t3(lang, 'Delete', 'हटाएँ', 'తొలగించు'))),
        ],
      ),
    );
    if (ok != true) return;
    await Notifications.cancelEvent(widget.existing!.id);
    await ref.read(eventsProvider.notifier).remove(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final scheme = Theme.of(context).colorScheme;
    final shukla = (_tithi ?? 1) <= 15;
    final inPaksha = ((_tithi ?? 1) - 1) % 15 + 1;
    final next = _preview();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: Palette.sunrise),
                    shape: BoxShape.circle,
                  ),
                  child: Text(UserEvent.emojiFor(_kind), style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? t3(lang, 'Add to my calendar', 'मेरे कैलेंडर में जोड़ें', 'నా క్యాలెండర్‌లో జోడించు')
                        : t3(lang, 'Edit', 'बदलें', 'మార్చు'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t3(lang, 'Name', 'नाम', 'పేరు'),
                hintText: t3(lang, "e.g. Amma's birthday", 'जैसे: माँ का जन्मदिन', 'ఉదా: అమ్మ పుట్టినరోజు'),
                prefixIcon: const Icon(Icons.edit_rounded),
              ),
            ),
            _label(t3(lang, 'What kind of day?', 'कैसा दिन?', 'ఏ రకమైన రోజు?')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in UserEvent.kinds)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text('${UserEvent.emojiFor(k)} ${UserEvent.kindLabel(lang, k)}'),
                    selected: _kind == k,
                    onSelected: (_) => _setKind(k),
                  ),
              ],
            ),
            _label(t3(lang, 'Date', 'तारीख', 'తేదీ')),
            Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _fmtDate(lang, _date),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      Text(
                        t3(lang, 'Change', 'बदलें', 'మార్చు'),
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _label(t3(lang, 'Repeats', 'दोहराव', 'పునరావృతం')),
            SegmentedButton<EventRepeat>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: EventRepeat.once, label: Text(t3(lang, 'Once', 'एक बार', 'ఒక్కసారి'))),
                ButtonSegment(value: EventRepeat.yearly, label: Text(t3(lang, 'Yearly', 'हर साल', 'ఏటా'))),
                ButtonSegment(value: EventRepeat.tithi, label: Text(t3(lang, 'By tithi', 'तिथि से', 'తిథి ప్రకారం'))),
              ],
              selected: {_repeat},
              onSelectionChanged: (s) => setState(() {
                _repeat = s.first;
                _repeatTouched = true;
              }),
            ),
            if (_repeat == EventRepeat.tithi) ...[
              const SizedBox(height: 10),
              Text(
                t3(
                  lang,
                  'Repeats every year on the same lunar month and tithi, the way families keep birthdays and remembrance days.',
                  'हर साल उसी चंद्र मास और तिथि पर आता है, जैसे परिवार जन्मदिन और श्राद्ध मनाते हैं।',
                  'ప్రతి సంవత్సరం అదే మాసం, తిథి నాడు వస్తుంది, కుటుంబాల్లో పుట్టినరోజు, తద్దినం పాటించినట్లే.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: t3(lang, 'Month', 'मास', 'మాసం')),
                      items: [
                        for (var i = 0; i < 12; i++) DropdownMenuItem(value: i, child: Text(lunarMonthLabel(lang, i))),
                      ],
                      onChanged: (v) => setState(() => _month = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      initialValue: shukla,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: t3(lang, 'Paksha', 'पक्ष', 'పక్షం')),
                      items: [
                        DropdownMenuItem(value: true, child: Text(t3(lang, 'Shukla', 'शुक्ल', 'శుక్ల'))),
                        DropdownMenuItem(value: false, child: Text(t3(lang, 'Krishna', 'कृष्ण', 'బహుళ'))),
                      ],
                      onChanged: (v) => setState(() => _tithi = inPaksha + (v == true ? 0 : 15)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                key: ValueKey(shukla),
                initialValue: _tithi == null ? null : inPaksha,
                isExpanded: true,
                decoration: InputDecoration(labelText: t3(lang, 'Tithi', 'तिथि', 'తిథి')),
                items: [
                  for (var i = 1; i <= 15; i++)
                    DropdownMenuItem(value: i, child: Text(tithiName(lang, i + (shukla ? 0 : 15)))),
                ],
                onChanged: (v) => setState(() => _tithi = (v ?? 1) + (shukla ? 0 : 15)),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.upcoming_rounded, color: scheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${t3(lang, 'Next', 'अगली बार', 'తదుపరి')}: ${_fmtDate(lang, next)}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
                      ),
                    ),
                    DaysLeft(next.difference(DateUtils.dateOnly(DateTime.now())).inDays, lang: lang),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.notifications_active_rounded, color: scheme.primary),
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
              title: Text(
                t3(lang, 'Remind me', 'याद दिलाएँ', 'గుర్తు చేయి'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                t3(
                  lang,
                  'The evening before (7 PM) and that morning (7 AM)',
                  'एक दिन पहले शाम 7 बजे और उस दिन सुबह 7 बजे',
                  'ముందు రోజు సాయంత్రం 7కు, ఆ రోజు ఉదయం 7కు',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(t3(lang, 'Save', 'सहेजें', 'సేవ్')),
            ),
            if (widget.existing != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(t3(lang, 'Delete', 'हटाएँ', 'తొలగించు')),
              ),
          ],
        ),
      ),
    );
  }
}

/// All personal events, soonest first.
class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final events = ref.watch(eventsProvider);
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final tithi = events.any((e) => e.repeat == EventRepeat.tithi);
    final thisYear = tithi ? ref.watch(yearDaysProvider(now.year)).value ?? const <Map>[] : const <Map>[];
    final nextYear = tithi ? ref.watch(yearDaysProvider(now.year + 1)).value ?? const <Map>[] : const <Map>[];
    final rows = [for (final e in events) (e, nextOccurrence(e, now, thisYear, nextYear))]
      ..sort((a, b) {
        if (a.$2 == null || b.$2 == null) return a.$2 == null ? (b.$2 == null ? 0 : 1) : -1;
        return a.$2!.compareTo(b.$2!);
      });
    final scheme = Theme.of(context).colorScheme;

    Widget quick(String kind, String label) => ActionChip(
      avatar: Text(UserEvent.emojiFor(kind)),
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.18),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      onPressed: () => showEventEditor(context, ref, kind: kind),
    );

    final intro = GradientCard(
      colors: Palette.dusk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎂  💐  🕯️', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 10),
          Text(
            t3(lang, 'Never miss a family day', 'परिवार का कोई दिन न भूलें', 'కుటుంబపు ఏ రోజూ మర్చిపోకండి'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            t3(
              lang,
              'Birthdays, wedding anniversaries and remembrance days, by date or by tithi, with a reminder the evening before.',
              'जन्मदिन, सालगिरह और श्राद्ध, तारीख या तिथि से, एक दिन पहले याद दिलाने के साथ।',
              'పుట్టినరోజులు, పెళ్లి రోజులు, తద్దినాలు: తేదీ లేదా తిథి ప్రకారం, ముందు రోజే గుర్తుచేస్తాం.',
            ),
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              quick('birthday', UserEvent.kindLabel(lang, 'birthday')),
              quick('anniversary', UserEvent.kindLabel(lang, 'anniversary')),
              quick('remembrance', t3(lang, 'Shraddha by tithi', 'तिथि से श्राद्ध', 'తిథి ప్రకారం తద్దినం')),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'My events', 'मेरे दिन', 'నా రోజులు'))),
      floatingActionButton: rows.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showEventEditor(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(t3(lang, 'Add', 'जोड़ें', 'జోడించు')),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (rows.isEmpty) intro,
          if (rows.isNotEmpty && rows.first.$2 != null)
            _NextUp(event: rows.first.$1, on: rows.first.$2!, today: today, lang: lang),
          if (rows.isNotEmpty) SectionHeader(t3(lang, 'All my days', 'मेरे सभी दिन', 'నా అన్ని రోజులు')),
          for (final (e, next) in rows)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                onTap: () => showEventEditor(context, ref, existing: e),
                leading: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
                  child: Text(e.emoji, style: const TextStyle(fontSize: 22)),
                ),
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([_repeatLabel(lang, e), if (next != null) _fmtDate(lang, next)].join('\n')),
                trailing: next == null ? null : DaysLeft(next.difference(today).inDays, lang: lang),
              ),
            ),
          if (tithi)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                t3(
                  lang,
                  'Tithi dates follow the sunrise tithi for your Panchang city. Confirm the day with your family priest for rituals.',
                  'तिथि की तारीख आपके पंचांग शहर के सूर्योदय तिथि से है। अनुष्ठान के लिए पुरोहित से पुष्टि करें।',
                  'తిథి తేదీలు మీ పంచాంగ నగరపు సూర్యోదయ తిథి ప్రకారం. కార్యక్రమాలకు పురోహితులను సంప్రదించండి.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => context.push('/calendar/important'),
              icon: const Icon(Icons.event_note_rounded),
              label: Text(
                t3(lang, 'See all important days', 'सभी महत्वपूर्ण दिन देखें', 'అన్ని ముఖ్యమైన రోజులు చూడండి'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The soonest personal day, in the app's sunrise gradient.
class _NextUp extends StatelessWidget {
  const _NextUp({required this.event, required this.on, required this.today, required this.lang});
  final UserEvent event;
  final DateTime on, today;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final days = on.difference(today).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GradientCard(
        colors: Palette.sunrise,
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  days <= 1 ? event.emoji : '$days',
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1),
                ),
                if (days > 1)
                  Text(
                    t3(lang, 'days', 'दिन', 'రోజులు'),
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (days) {
                    0 => t3(lang, 'Today', 'आज', 'ఈరోజు'),
                    1 => t3(lang, 'Tomorrow', 'कल', 'రేపు'),
                    _ => t3(lang, 'Coming up', 'आने वाला', 'రాబోయేది'),
                  }, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  Text(
                    event.title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    [_fmtDate(lang, on), if (event.repeat == EventRepeat.tithi) event.tithiLabel(lang)].join(' · '),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tag used in lists for the days left.
class DaysLeft extends StatelessWidget {
  const DaysLeft(this.days, {super.key, required this.lang});
  final int days;
  final String lang;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final soon = days <= 1;
    final text = switch (days) {
      0 => t3(lang, 'Today', 'आज', 'ఈరోజు'),
      1 => t3(lang, 'Tomorrow', 'कल', 'రేపు'),
      _ => t3(lang, 'in $days days', '$days दिन में', '$days రోజుల్లో'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: soon ? const LinearGradient(colors: Palette.sunrise) : null,
        color: soon ? null : scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: soon ? Colors.white : scheme.primary),
      ),
    );
  }
}
