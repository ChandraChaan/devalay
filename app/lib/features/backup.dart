import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/events.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/names.dart';
import '../core/portability.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Backup and restore, the calendar file and the contacts import, all on the phone.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  String get _lang => ref.read(prefsProvider).language;

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } catch (_) {
      if (mounted) toast(context, t3(_lang, 'Something went wrong', 'कुछ गड़बड़ हुई', 'ఏదో పొరపాటు జరిగింది'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _backupText() =>
      const JsonEncoder.withIndent('  ').convert(buildBackup(Boxes.prefs, ref.read(eventsProvider), DateTime.now()));

  Future<void> _save() => _run(() async {
    final ok = await Portability.saveFile(backupFileName(DateTime.now()), _backupText());
    if (ok != true) return;
    await markBackedUp();
    if (mounted) toast(context, t3(_lang, 'Backup saved', 'बैकअप सहेजा गया', 'బ్యాకప్ సేవ్ అయింది'));
  });

  Future<void> _share() => _run(() async {
    await shareTextFile(backupFileName(DateTime.now()), _backupText(), 'application/json', subject: 'Devalay backup');
    await markBackedUp();
  });

  Future<void> _restore() => _run(() async {
    final lang = _lang;
    final text = await Portability.openFile();
    if (text == null || !mounted) return;
    final Backup backup;
    try {
      backup = parseBackup(text);
    } on FormatException {
      toast(
        context,
        t3(lang, 'This file is not a Devalay backup', 'यह देवालय बैकअप फ़ाइल नहीं है', 'ఇది దేవాలయం బ్యాకప్ ఫైల్ కాదు'),
      );
      return;
    }
    final counts = mergeCount(ref.read(eventsProvider), backup.events);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t3(lang, 'Restore this backup?', 'यह बैकअप वापस लाएँ?', 'ఈ బ్యాకప్‌ను పునరుద్ధరించాలా?')),
        content: Text(
          [
            if (backup.created != null) fmtDate(lang, 'd MMM y', backup.created!.toLocal()),
            t3(lang, 'New days: ${counts.added}', 'नए दिन: ${counts.added}', 'కొత్త రోజులు: ${counts.added}'),
            t3(
              lang,
              'Updated days: ${counts.updated}',
              'बदले गए दिन: ${counts.updated}',
              'మారిన రోజులు: ${counts.updated}',
            ),
            if (backup.prefs.isNotEmpty)
              t3(
                lang,
                'Language, city, birth star and reminder settings are replaced by the backup.',
                'भाषा, शहर, जन्म नक्षत्र और रिमाइंडर सेटिंग बैकअप से बदल दी जाएँगी।',
                'భాష, నగరం, జన్మ నక్షత్రం, రిమైండర్ సెట్టింగ్‌లు బ్యాకప్‌లోనివిగా మారతాయి.',
              ),
            t3(
              lang,
              'Days already on this phone are kept.',
              'इस फ़ोन पर पहले से मौजूद दिन बने रहेंगे।',
              'ఈ ఫోన్‌లో ఇప్పటికే ఉన్న రోజులు అలాగే ఉంటాయి.',
            ),
          ].join('\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t3(lang, 'Cancel', 'रद्द करें', 'రద్దు'))),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t3(lang, 'Restore', 'वापस लाएँ', 'పునరుద్ధరించు')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await applyBackup(ref, backup);
    if (mounted) toast(context, t3(_lang, 'Restored', 'वापस आ गया', 'పునరుద్ధరించబడింది'));
  });

  Future<void> _contacts() async {
    if (!await showContactsDisclosure(context, _lang) || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ContactImportScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    ref.watch(eventsProvider);
    final last = lastBackupAt;
    final changes = unsavedEventChanges;
    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap) =>
        ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), enabled: !_busy, onTap: onTap);

    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Backup & export', 'बैकअप और एक्सपोर्ट', 'బ్యాకప్ & ఎక్స్‌పోర్ట్'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GradientCard(
              colors: Palette.dusk,
              padding: 16,
              child: Text(
                t3(
                  lang,
                  'Your days and settings live only on this phone. Keep a backup file to move them to a new phone. No account, nothing uploaded.',
                  'आपके दिन और सेटिंग केवल इसी फ़ोन पर हैं। नए फ़ोन में ले जाने के लिए बैकअप फ़ाइल रखें। कोई खाता नहीं, कुछ भी अपलोड नहीं।',
                  'మీ రోజులు, సెట్టింగ్‌లు ఈ ఫోన్‌లోనే ఉంటాయి. కొత్త ఫోన్‌కు తీసుకెళ్లడానికి బ్యాకప్ ఫైల్ ఉంచుకోండి. ఖాతా అవసరం లేదు, ఏదీ అప్‌లోడ్ కాదు.',
                ),
                style: const TextStyle(color: Colors.white, height: 1.45),
              ),
            ),
          ),
          SectionHeader(t3(lang, 'Backup', 'बैकअप', 'బ్యాకప్')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              [
                last == null
                    ? t3(lang, 'Not backed up yet', 'अभी तक बैकअप नहीं', 'ఇంకా బ్యాకప్ చేయలేదు')
                    : '${t3(lang, 'Last backup', 'पिछला बैकअप', 'చివరి బ్యాకప్')}: ${fmtDate(lang, 'd MMM y', last)}',
                if (changes > 0)
                  t3(
                    lang,
                    'Changes since last backup: $changes',
                    'पिछले बैकअप के बाद बदलाव: $changes',
                    'చివరి బ్యాకప్ తర్వాత మార్పులు: $changes',
                  ),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          tile(
            Icons.save_alt_rounded,
            t3(lang, 'Save backup file', 'बैकअप फ़ाइल सहेजें', 'బ్యాకప్ ఫైల్ సేవ్ చేయండి'),
            t3(
              lang,
              'Pick a folder, Google Drive or SD card',
              'कोई फ़ोल्डर, Google Drive या SD कार्ड चुनें',
              'ఫోల్డర్, Google Drive లేదా SD కార్డ్ ఎంచుకోండి',
            ),
            _save,
          ),
          tile(
            Icons.share_rounded,
            t3(lang, 'Share backup file', 'बैकअप फ़ाइल शेयर करें', 'బ్యాకప్ ఫైల్ షేర్ చేయండి'),
            t3(
              lang,
              'Send it to yourself by email or chat',
              'ईमेल या चैट से खुद को भेजें',
              'ఈమెయిల్ లేదా చాట్‌లో మీకే పంపుకోండి',
            ),
            _share,
          ),
          tile(
            Icons.settings_backup_restore_rounded,
            t3(lang, 'Restore from a backup file', 'बैकअप फ़ाइल से वापस लाएँ', 'బ్యాకప్ ఫైల్ నుండి పునరుద్ధరించండి'),
            t3(
              lang,
              'Adds your saved days and settings back',
              'सहेजे गए दिन और सेटिंग वापस जोड़ता है',
              'దాచిన రోజులు, సెట్టింగ్‌లను మళ్ళీ చేర్చుతుంది',
            ),
            _restore,
          ),
          SectionHeader(t3(lang, 'Calendar', 'कैलेंडर', 'క్యాలెండర్')),
          tile(
            Icons.event_available_rounded,
            t3(lang, 'Export to calendar (.ics)', 'कैलेंडर में एक्सपोर्ट (.ics)', 'క్యాలెండర్‌కు ఎక్స్‌పోర్ట్ (.ics)'),
            t3(
              lang,
              'Festivals and your days, for Google Calendar or any calendar app',
              'त्योहार और आपके दिन, Google Calendar या किसी भी कैलेंडर ऐप के लिए',
              'పండుగలు, మీ రోజులు: Google Calendar లేదా ఏ క్యాలెండర్ యాప్‌కైనా',
            ),
            () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (_) => const _IcsSheet(),
            ),
          ),
          SectionHeader(t3(lang, 'Contacts', 'संपर्क', 'కాంటాక్ట్‌లు')),
          tile(
            Icons.cake_rounded,
            t3(
              lang,
              'Import birthdays from contacts',
              'संपर्कों से जन्मदिन लाएँ',
              'కాంటాక్ట్‌ల నుండి పుట్టినరోజులు తీసుకురండి',
            ),
            t3(
              lang,
              'Birthdays and anniversaries saved in your contacts',
              'आपके संपर्कों में सहेजे जन्मदिन और सालगिरह',
              'మీ కాంటాక్ట్‌లలో ఉన్న పుట్టినరోజులు, వివాహ వార్షికోత్సవాలు',
            ),
            _contacts,
          ),
        ],
      ),
    );
  }
}

/// Year and contents of the .ics file, then share or save it.
class _IcsSheet extends ConsumerStatefulWidget {
  const _IcsSheet();

  @override
  ConsumerState<_IcsSheet> createState() => _IcsSheetState();
}

class _IcsSheetState extends ConsumerState<_IcsSheet> {
  late int _year = DateTime.now().year;
  bool _majorOnly = false;
  bool _mine = true;
  bool _busy = false;

  Future<String> _build() async {
    final lang = ref.read(prefsProvider).language;
    final now = DateTime.now();
    final festivals = await ref.read(festivalsProvider(_year).future).catchError((Object _) => <Festival>[]);
    final events = _mine ? ref.read(eventsProvider) : const <UserEvent>[];
    final tithi = events.any((e) => e.repeat == EventRepeat.tithi);
    final days = <int, List<Map>>{
      if (tithi)
        for (final y in [now.year, now.year + 1])
          y: await ref.read(yearDaysProvider(y).future).catchError((Object _) => <Map>[]),
    };
    return buildIcs(
      lang: lang,
      festivals: festivals.where((f) => !_majorOnly || f.major),
      events: events,
      tithiDays: days,
      now: now,
    );
  }

  Future<void> _go(bool share) async {
    final lang = ref.read(prefsProvider).language;
    setState(() => _busy = true);
    try {
      final ics = await _build();
      final name = 'devalay-$_year.ics';
      if (share) {
        await shareTextFile(name, ics, 'text/calendar', subject: 'Devalay $_year');
      } else if (await Portability.saveFile(name, ics, mime: 'text/calendar') == true && mounted) {
        toast(context, t3(lang, 'Calendar file saved', 'कैलेंडर फ़ाइल सहेजी गई', 'క్యాలెండర్ ఫైల్ సేవ్ అయింది'));
      }
    } catch (_) {
      if (mounted) toast(context, t3(lang, 'Something went wrong', 'कुछ गड़बड़ हुई', 'ఏదో పొరపాటు జరిగింది'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final now = DateTime.now().year;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t3(lang, 'Export to calendar (.ics)', 'कैलेंडर में एक्सपोर्ट (.ics)', 'క్యాలెండర్‌కు ఎక్స్‌పోర్ట్ (.ics)'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [
              for (final y in [now, now + 1]) ButtonSegment(value: y, label: Text('$y')),
            ],
            selected: {_year},
            onSelectionChanged: (s) => setState(() => _year = s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _majorOnly,
            onChanged: (v) => setState(() => _majorOnly = v),
            title: Text(t3(lang, 'Major festivals only', 'केवल बड़े त्योहार', 'పెద్ద పండుగలు మాత్రమే')),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _mine,
            onChanged: (v) => setState(() => _mine = v),
            title: Text(t3(lang, 'Include my days', 'मेरे दिन भी जोड़ें', 'నా రోజులు కూడా చేర్చండి')),
            subtitle: Text(
              t3(
                lang,
                'Date-based days repeat every year; tithi days are listed for this year and next.',
                'तारीख वाले दिन हर साल दोहराए जाते हैं; तिथि वाले दिन इस और अगले साल के लिए।',
                'తేదీ రోజులు ప్రతి సంవత్సరం వస్తాయి; తిథి రోజులు ఈ ఏడాది, వచ్చే ఏడాదికి.',
              ),
            ),
          ),
          Text(
            t3(
              lang,
              'Open the file in your calendar app. In Google Calendar on the web, use Settings → Import & export.',
              'फ़ाइल को अपने कैलेंडर ऐप में खोलें। वेब पर Google Calendar में Settings → Import & export चुनें।',
              'ఫైల్‌ను మీ క్యాలెండర్ యాప్‌లో తెరవండి. వెబ్‌లో Google Calendarలో Settings → Import & export వాడండి.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _go(false),
                  icon: const Icon(Icons.save_alt_rounded),
                  label: Text(t3(lang, 'Save', 'सहेजें', 'సేవ్')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _go(true),
                  icon: const Icon(Icons.share_rounded),
                  label: Text(t3(lang, 'Share', 'शेयर करें', 'షేర్ చేయండి')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The prominent disclosure Google Play requires before asking for Contacts permission. True when the
/// user continues.
Future<bool> showContactsDisclosure(BuildContext context, String lang) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.contacts_rounded),
        title: Text(t3(lang, 'Contacts access', 'संपर्कों तक पहुँच', 'కాంటాక్ట్‌ల యాక్సెస్')),
        content: SingleChildScrollView(
          child: Text(
            t3(
              lang,
              'Devalay will read the birthdays and anniversaries saved in your phone contacts, with each contact\'s name, so you can choose which to add to My events.\n\nThis stays on your phone: nothing is uploaded or shared, and only the days you choose are kept. Android will now ask for Contacts permission. You can turn it off any time in the phone\'s settings.',
              'देवालय आपके फ़ोन संपर्कों में सहेजे जन्मदिन और सालगिरह, संपर्क के नाम के साथ, पढ़ेगा ताकि आप चुन सकें कि मेरे दिन में क्या जोड़ना है।\n\nयह आपके फ़ोन पर ही रहता है: कुछ भी अपलोड या शेयर नहीं होता, केवल आपके चुने दिन रखे जाते हैं। अब Android संपर्क अनुमति माँगेगा। आप इसे कभी भी फ़ोन की सेटिंग में बंद कर सकते हैं।',
              'మీరు నా రోజులులో ఏవి చేర్చాలో ఎంచుకునేందుకు, దేవాలయం మీ ఫోన్ కాంటాక్ట్‌లలో ఉన్న పుట్టినరోజులు, వివాహ వార్షికోత్సవాలను పేర్లతో సహా చదువుతుంది.\n\nఇది మీ ఫోన్‌లోనే ఉంటుంది: ఏదీ అప్‌లోడ్ లేదా షేర్ కాదు, మీరు ఎంచుకున్న రోజులు మాత్రమే ఉంచుతాం. ఇప్పుడు Android కాంటాక్ట్‌ల అనుమతి అడుగుతుంది. ఫోన్ సెట్టింగ్‌లలో ఎప్పుడైనా ఆపేయవచ్చు.',
            ),
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t3(lang, 'Not now', 'अभी नहीं', 'ఇప్పుడు కాదు')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t3(lang, 'Continue', 'जारी रखें', 'కొనసాగించు')),
          ),
        ],
      ),
    ) ==
    true;

/// Lists the contacts' birthdays and anniversaries for the user to pick from.
class ContactImportScreen extends ConsumerStatefulWidget {
  const ContactImportScreen({super.key});

  @override
  ConsumerState<ContactImportScreen> createState() => _ContactImportScreenState();
}

class _ContactImportScreenState extends ConsumerState<ContactImportScreen> {
  List<ContactDay>? _days;
  final _chosen = <String>{};
  bool _denied = false;
  bool _remind = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!await Portability.requestContactsPermission()) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      final days = contactDays(await Portability.contactEvents(), DateTime.now());
      final existing = {for (final e in ref.read(eventsProvider)) e.id};
      if (!mounted) return;
      setState(() {
        _days = days;
        _chosen.addAll(days.where((d) => !existing.contains(d.id)).map((d) => d.id));
      });
    } catch (_) {
      if (mounted) setState(() => _days = const []);
    }
  }

  Future<void> _import() async {
    final lang = ref.read(prefsProvider).language;
    final picked = [
      for (final d in _days ?? const <ContactDay>[])
        if (_chosen.contains(d.id)) d,
    ];
    if (picked.isEmpty) return;
    setState(() => _saving = true);
    await importContactDays(ref, picked, remind: _remind);
    if (!mounted) return;
    Navigator.of(context).pop();
    toast(
      context,
      t3(lang, 'Added ${picked.length} days', '${picked.length} दिन जोड़े गए', '${picked.length} రోజులు చేర్చాం'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final existing = {for (final e in ref.watch(eventsProvider)) e.id};
    final days = _days;
    final title = t3(lang, 'Import from contacts', 'संपर्कों से लाएँ', 'కాంటాక్ట్‌ల నుండి తీసుకురండి');

    Widget message(String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );

    final Widget body;
    if (_denied) {
      body = message(
        t3(
          lang,
          'Contacts permission was not given. Nothing was read.',
          'संपर्क अनुमति नहीं मिली। कुछ भी नहीं पढ़ा गया।',
          'కాంటాక్ట్‌ల అనుమతి ఇవ్వలేదు. ఏదీ చదవలేదు.',
        ),
      );
    } else if (days == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (days.isEmpty) {
      body = message(
        t3(
          lang,
          'No birthdays or anniversaries found in your contacts',
          'आपके संपर्कों में कोई जन्मदिन या सालगिरह नहीं मिली',
          'మీ కాంటాక్ట్‌లలో పుట్టినరోజులు లేదా వార్షికోత్సవాలు లేవు',
        ),
      );
    } else {
      final all = days.every((d) => _chosen.contains(d.id));
      body = Column(
        children: [
          CheckboxListTile(
            value: all,
            onChanged: (v) => setState(() => v == true ? _chosen.addAll(days.map((d) => d.id)) : _chosen.clear()),
            title: Text(t3(lang, 'Select all', 'सभी चुनें', 'అన్నీ ఎంచుకోండి')),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: days.length,
              itemBuilder: (_, i) {
                final d = days[i];
                return CheckboxListTile(
                  value: _chosen.contains(d.id),
                  onChanged: (v) => setState(() => v == true ? _chosen.add(d.id) : _chosen.remove(d.id)),
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: Text(UserEvent.emojiFor(d.kind), style: const TextStyle(fontSize: 22)),
                  title: Text(d.name),
                  subtitle: Text(
                    [
                      UserEvent.kindLabel(lang, d.kind),
                      fmtDate(lang, d.hasYear ? 'd MMM y' : 'd MMM', d.date),
                      if (existing.contains(d.id)) t3(lang, 'Already added', 'पहले से जोड़ा', 'ఇప్పటికే చేర్చారు'),
                    ].join(' · '),
                  ),
                );
              },
            ),
          ),
          SwitchListTile(
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
            title: Text(
              t3(lang, 'Remind me the evening before', 'एक शाम पहले याद दिलाएँ', 'ముందు రోజు సాయంత్రం గుర్తు చేయండి'),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || _chosen.isEmpty ? null : _import,
                  icon: const Icon(Icons.download_done_rounded),
                  label: Text(
                    t3(
                      lang,
                      'Import (${_chosen.length})',
                      'जोड़ें (${_chosen.length})',
                      'చేర్చండి (${_chosen.length})',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

/// "Add to calendar" for one festival: the phone's calendar app opens with it filled in.
Future<void> addFestivalToCalendar(BuildContext context, String lang, Festival f) => _add(
  context,
  lang,
  () => Portability.addToCalendar(
    title: '${f.major ? '🪔' : '🙏'} ${f.label(lang)}',
    day: f.date,
    description: f.describe(lang),
  ),
);

/// "Add to calendar" for a personal day: date-based days repeat yearly; a tithi day is added for
/// its next date ([next]), since its English date moves every year.
Future<void> addEventToCalendar(BuildContext context, String lang, UserEvent e, {DateTime? next}) => _add(
  context,
  lang,
  () => Portability.addToCalendar(
    title: '${e.emoji} ${e.title}',
    day: e.repeat == EventRepeat.tithi ? (next ?? e.date) : e.date,
    description: [UserEvent.kindLabel(lang, e.kind), if (e.repeat == EventRepeat.tithi) e.tithiLabel(lang)].join(' · '),
    yearly: e.repeat == EventRepeat.yearly,
  ),
);

Future<void> _add(BuildContext context, String lang, Future<bool> Function() open) async {
  var ok = false;
  try {
    ok = await open();
  } catch (_) {}
  if (!ok && context.mounted) {
    toast(context, t3(lang, 'No calendar app found', 'कोई कैलेंडर ऐप नहीं मिला', 'క్యాలెండర్ యాప్ కనబడలేదు'));
  }
}

/// After a few unsaved changes to My events, a snackbar suggests a backup (at most once a fortnight).
/// True when it was shown.
bool suggestBackupIfDue(BuildContext context, String lang) {
  if (!takeBackupSuggestion()) return false;
  final router = GoRouter.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          t3(
            lang,
            'Back up your days so a new phone keeps them.',
            'अपने दिनों का बैकअप लें ताकि नया फ़ोन उन्हें रखे।',
            'కొత్త ఫోన్‌లోనూ ఉండేలా మీ రోజులను బ్యాకప్ చేయండి.',
          ),
        ),
        action: SnackBarAction(
          label: t3(lang, 'Back up', 'बैकअप लें', 'బ్యాకప్'),
          onPressed: () => router.push('/backup'),
        ),
      ),
    );
  return true;
}
