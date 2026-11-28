import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/account.dart';
import '../core/calendar_reminders.dart';
import '../core/firebase.dart';
import '../core/i18n.dart';
import '../core/jyotish.dart';
import '../core/muhurta.dart';
import '../core/names.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../core/about_you.dart';
import '../widgets/city_picker.dart';
import '../widgets/common.dart';

/// "About you" (Settings, and the last onboarding page): name, gender and birth details, the stars
/// worked out from them, and the optional Google backup.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late AboutYou _draft = ref.read(aboutYouProvider);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(aboutYouProvider.notifier).save(_draft);
    Usage.record('profile_saved');
    unawaited(refreshCalendarReminders(ref));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _draft = ref.read(aboutYouProvider);
    });
    final lang = ref.read(prefsProvider).language;
    toast(context, t3(lang, 'Saved', 'सहेजा गया', 'సేవ్ అయింది'));
  }

  Future<void> _remove() async {
    final lang = ref.read(prefsProvider).language;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t3(lang, 'Remove your details?', 'अपना विवरण हटाएँ?', 'మీ వివరాలు తొలగించాలా?')),
        content: Text(
          t3(
            lang,
            'Your name, birth details and stars are removed from this phone, from your Google backup and from the usage statistics.',
            'आपका नाम, जन्म विवरण और नक्षत्र इस फ़ोन से, आपके Google बैकअप से और उपयोग के आँकड़ों से हटा दिए जाएँगे।',
            'మీ పేరు, పుట్టిన వివరాలు, నక్షత్రాలు ఈ ఫోన్ నుంచి, మీ Google బ్యాకప్ నుంచి, వినియోగ గణాంకాల నుంచి తొలగిపోతాయి.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t3(lang, 'Cancel', 'रद्द करें', 'రద్దు')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t3(lang, 'Remove', 'हटाएँ', 'తొలగించు')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(aboutYouProvider.notifier).clear(stars: true);
    Usage.record('profile_removed');
    unawaited(refreshCalendarReminders(ref));
    if (mounted) setState(() => _draft = AboutYou.empty);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final saved = ref.watch(aboutYouProvider);
    final changed = _draft != saved;
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'About you', 'आपके बारे में', 'మీ గురించి'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32).withSystemInsets(context),
        children: [
          Text(
            t3(
              lang,
              'Everything here is optional. With your birth details Devalay shows your own Tarabalam and Chandrabalam each day, opens your Jatakam ready and wishes you on your birthday.',
              'यहाँ सब कुछ वैकल्पिक है। जन्म विवरण से देवालय हर दिन आपका तारा बल और चंद्र बल दिखाता है, आपकी जन्म कुंडली तैयार खोलता है और जन्मदिन पर शुभकामना देता है।',
              'ఇక్కడ అన్నీ ఐచ్ఛికం. మీ పుట్టిన వివరాలతో దేవాలయం ప్రతి రోజు మీ తారాబలం, చంద్రబలం చూపిస్తుంది, మీ జాతకం సిద్ధంగా తెరుస్తుంది, పుట్టినరోజున శుభాకాంక్షలు చెబుతుంది.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ProfileForm(value: _draft, onChanged: (p) => setState(() => _draft = p)),
            ),
          ),
          const SizedBox(height: 12),
          _StarsCard(profile: _draft, onChanged: (p) => setState(() => _draft = p)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving || !changed ? null : _save,
            icon: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(t3(lang, 'Save', 'सहेजें', 'సేవ్')),
          ),
          const SizedBox(height: 20),
          if (FirebaseServices.enabled) const GoogleBackupCard(),
          const SizedBox(height: 12),
          Text(
            t3(
              lang,
              'Kept on this phone. While "Share usage statistics" is on (Settings → Privacy), your name, gender, date, time and city of birth, gotra and stars are also shared with the Devalay developer to improve the app; never for advertising.',
              'यह इसी फ़ोन पर रहता है। जब तक "उपयोग के आँकड़े साझा करें" चालू है (सेटिंग्स → गोपनीयता), आपका नाम, लिंग, जन्म की तिथि, समय और शहर, गोत्र और नक्षत्र ऐप बेहतर बनाने के लिए देवालय के डेवलपर से भी साझा होते हैं; विज्ञापन के लिए कभी नहीं।',
              'ఇది ఈ ఫోన్‌లోనే ఉంటుంది. "వినియోగ గణాంకాలు పంచుకోండి" ఆన్‌లో ఉన్నంత వరకు (సెట్టింగ్‌లు → గోప్యత), మీ పేరు, లింగం, పుట్టిన తేదీ, సమయం, నగరం, గోత్రం, నక్షత్రాలు యాప్‌ను మెరుగుపరచడానికి దేవాలయం డెవలపర్‌తో కూడా పంచుకుంటాం; ప్రకటనల కోసం ఎప్పుడూ కాదు.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!saved.isEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(t3(lang, 'Remove my details', 'मेरा विवरण हटाएँ', 'నా వివరాలు తొలగించు')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The editable fields of "About you", on the profile screen and the last onboarding page.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, required this.value, required this.onChanged, this.showGotra = true});
  final AboutYou value;
  final ValueChanged<AboutYou> onChanged;
  final bool showGotra;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  late final _name = TextEditingController(text: widget.value.name);
  late final _gotra = TextEditingController(text: widget.value.gotra);

  @override
  void didUpdateWidget(ProfileForm old) {
    super.didUpdateWidget(old);
    // A profile restored or removed from outside the form.
    if (widget.value.name != _name.text) _name.text = widget.value.name;
    if (widget.value.gotra != _gotra.text) _gotra.text = widget.value.gotra;
  }

  @override
  void dispose() {
    _name.dispose();
    _gotra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final p = widget.value;
    final dob = p.birthDate;
    final tob = p.birthMinutes;
    String genderLabel(Gender g) => switch (g) {
      Gender.male => t3(lang, 'Male', 'पुरुष', 'పురుషుడు'),
      Gender.female => t3(lang, 'Female', 'महिला', 'స్త్రీ'),
      Gender.other => t3(lang, 'Other', 'अन्य', 'ఇతర'),
    };
    final city = p.placeId == null ? null : cityById(p.placeId!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: t3(lang, 'Your name', 'आपका नाम', 'మీ పేరు'),
            counterText: '',
            prefixIcon: const Icon(Icons.person_rounded),
          ),
          onChanged: (v) => widget.onChanged(p.copyWith(name: v.trim())),
        ),
        const SizedBox(height: 12),
        SegmentedButton<Gender>(
          segments: [for (final g in Gender.values) ButtonSegment(value: g, label: Text(genderLabel(g)))],
          selected: {?p.gender},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (s) => widget.onChanged(p.copyWith(gender: () => s.isEmpty ? null : s.first)),
        ),
        const SizedBox(height: 12),
        _PickerRow(
          icon: Icons.cake_rounded,
          label: t3(lang, 'Date of birth', 'जन्म तिथि', 'పుట్టిన తేదీ'),
          value: dob == null ? null : fmtDate(lang, 'd MMM yyyy', dob),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: dob ?? DateTime(now.year - 30, now.month, now.day),
              firstDate: DateTime(1900),
              lastDate: now,
              // The pencil switches to typing the date, quicker than paging back decades.
              initialEntryMode: DatePickerEntryMode.calendar,
            );
            if (d != null) widget.onChanged(p.copyWith(birthDate: () => DateTime(d.year, d.month, d.day)));
          },
          onClear: dob == null ? null : () => widget.onChanged(p.copyWith(birthDate: () => null)),
        ),
        _PickerRow(
          icon: Icons.schedule_rounded,
          label: t3(lang, 'Time of birth', 'जन्म का समय', 'పుట్టిన సమయం'),
          value: tob == null ? null : hourMinute(lang, DateTime(2000, 1, 1, tob ~/ 60, tob % 60)),
          hint: t3(lang, 'Needed for your lagna', 'लग्न के लिए ज़रूरी', 'లగ్నం కోసం అవసరం'),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: tob == null
                  ? const TimeOfDay(hour: 6, minute: 0)
                  : TimeOfDay(hour: tob ~/ 60, minute: tob % 60),
            );
            if (t != null) widget.onChanged(p.copyWith(birthMinutes: () => t.hour * 60 + t.minute));
          },
          onClear: tob == null ? null : () => widget.onChanged(p.copyWith(birthMinutes: () => null)),
        ),
        _PickerRow(
          icon: Icons.place_rounded,
          label: t3(lang, 'Place of birth', 'जन्म स्थान', 'పుట్టిన స్థలం'),
          value: city?.label(lang) ?? (p.place.isEmpty ? null : p.place),
          onTap: () async {
            final c = await pickBirthPlace(context, selectedId: p.placeId);
            if (c != null) widget.onChanged(p.copyWith(city: () => c));
          },
          onClear: p.placeId == null ? null : () => widget.onChanged(p.copyWith(city: () => null)),
        ),
        if (widget.showGotra) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _gotra,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: t3(lang, 'Gotra (optional)', 'गोत्र (वैकल्पिक)', 'గోత్రం (ఐచ్ఛికం)'),
              counterText: '',
              prefixIcon: const Icon(Icons.family_restroom_rounded),
            ),
            onChanged: (v) => widget.onChanged(p.copyWith(gotra: v.trim())),
          ),
        ],
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.hint,
  });
  final IconData icon;
  final String label;
  final String? value;
  final String? hint;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: scheme.primary),
      title: Text(label),
      subtitle: Text(value ?? hint ?? '—', style: value == null ? null : const TextStyle(fontWeight: FontWeight.w700)),
      trailing: onClear == null
          ? const Icon(Icons.chevron_right_rounded)
          : IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onClear,
            ),
      onTap: onTap,
    );
  }
}

/// Rashi, nakshatra and lagna: worked out from the birth details, or set by hand from the user's horoscope.
class _StarsCard extends ConsumerWidget {
  const _StarsCard({required this.profile, required this.onChanged});
  final AboutYou profile;
  final ValueChanged<AboutYou> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    // What saving will keep: the hand-set stars, or what the birth details give now.
    final shown = profile.withComputedStars();
    final rows = <(String, String)>[
      (
        t3(lang, 'Rashi (moon sign)', 'राशि (चंद्र राशि)', 'రాశి (చంద్ర రాశి)'),
        shown.rashi == null ? '—' : rashiLabel(lang, shown.rashi!),
      ),
      (
        t3(lang, 'Nakshatra', 'नक्षत्र', 'నక్షత్రం'),
        shown.nakshatra == null
            ? '—'
            : '${nakshatraLabel(lang, shown.nakshatra!)}${shown.pada == null ? '' : ' · ${t3(lang, 'pada', 'चरण', 'పాదం')} ${shown.pada}'}',
      ),
      (t3(lang, 'Lagna', 'लग्न', 'లగ్నం'), shown.lagna == null ? '—' : rashiLabel(lang, shown.lagna!)),
    ];
    final note = profile.starsByHand
        ? t3(lang, 'Set by you.', 'आपने चुना।', 'మీరు ఎంచుకున్నవి.')
        : profile.birthDate == null || !profile.hasPlace
        ? t3(
            lang,
            'Add your date and place of birth to work these out, or set them from your horoscope.',
            'इन्हें निकालने के लिए जन्म तिथि और स्थान जोड़ें, या अपनी कुंडली से चुनें।',
            'వీటిని లెక్కించడానికి పుట్టిన తేదీ, స్థలం ఇవ్వండి, లేదా మీ జాతకం నుంచి ఎంచుకోండి.',
          )
        : profile.birthMinutes == null
        ? t3(
            lang,
            'Worked out from your date and place of birth. Add the time of birth for the lagna.',
            'जन्म तिथि और स्थान से निकाला गया। लग्न के लिए जन्म का समय जोड़ें।',
            'పుట్టిన తేదీ, స్థలం నుంచి లెక్కించాం. లగ్నం కోసం పుట్టిన సమయం ఇవ్వండి.',
          )
        : t3(
            lang,
            'Worked out from your birth details (Lahiri ayanamsa).',
            'आपके जन्म विवरण से निकाला गया (लाहिड़ी अयनांश)।',
            'మీ పుట్టిన వివరాల నుంచి లెక్కించాం (లాహిరి అయనాంశ).',
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t3(lang, 'Your stars', 'आपके नक्षत्र', 'మీ నక్షత్రాలు'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(k)),
                    Flexible(
                      child: Text(
                        v,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () async {
                    final p = await showModalBottomSheet<AboutYou>(
                      context: context,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (_) => _StarsSheet(profile: shown),
                    );
                    if (p != null) onChanged(p);
                  },
                  child: Text(t3(lang, 'I know mine: set them', 'मुझे पता है: चुनें', 'నాకు తెలుసు: ఎంచుకుంటాను')),
                ),
                if (profile.starsByHand && profile.birthDate != null && profile.hasPlace)
                  TextButton(
                    onPressed: () => onChanged(profile.copyWith(starsByHand: false)),
                    child: Text(
                      t3(
                        lang,
                        'Work out from birth details',
                        'जन्म विवरण से निकालें',
                        'పుట్టిన వివరాల నుంచి లెక్కించు',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StarsSheet extends ConsumerStatefulWidget {
  const _StarsSheet({required this.profile});
  final AboutYou profile;
  @override
  ConsumerState<_StarsSheet> createState() => _StarsSheetState();
}

class _StarsSheetState extends ConsumerState<_StarsSheet> {
  late int? _rashi = widget.profile.rashi;
  late int? _star = widget.profile.nakshatra;
  late int? _pada = widget.profile.pada;
  late int? _lagna = widget.profile.lagna;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    Widget drop(String label, int? value, int count, String Function(int) name, ValueChanged<int?> set) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int?>(
        key: ValueKey('$label$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: null, child: Text('—')),
          for (var i = 0; i < count; i++) DropdownMenuItem(value: i, child: Text(name(i))),
        ],
        onChanged: set,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom).withSystemInsets(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t3(lang, 'Your stars', 'आपके नक्षत्र', 'మీ నక్షత్రాలు'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              t3(
                lang,
                'From your horoscope (jatakam), if you know them.',
                'अपनी जन्म कुंडली से, अगर आपको पता हो।',
                'మీ జాతకం నుంచి, మీకు తెలిస్తే.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            drop(t3(lang, 'Nakshatra', 'नक्षत्र', 'నక్షత్రం'), _star, 27, (i) => nakshatraLabel(lang, i), (v) {
              setState(() {
                _star = v;
                _pada = null;
                if (v != null) _rashi = rashiOfStar(v);
              });
            }),
            drop(
              t3(lang, 'Pada', 'चरण', 'పాదం'),
              _pada == null ? null : _pada! - 1,
              4,
              (i) => '${i + 1}',
              (v) => setState(() => _pada = v == null ? null : v + 1),
            ),
            drop(
              t3(lang, 'Rashi (moon sign)', 'राशि (चंद्र राशि)', 'రాశి (చంద్ర రాశి)'),
              _rashi,
              12,
              (i) => rashiLabel(lang, i),
              (v) => setState(() => _rashi = v),
            ),
            drop(
              t3(lang, 'Lagna', 'लग्न', 'లగ్నం'),
              _lagna,
              12,
              (i) => rashiLabel(lang, i),
              (v) => setState(() => _lagna = v),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                widget.profile.copyWith(
                  rashi: () => _rashi,
                  nakshatra: () => _star,
                  pada: () => _star == null ? null : _pada,
                  lagna: () => _lagna,
                  starsByHand: true,
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: Text(t3(lang, 'Done', 'हो गया', 'సరే')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sign in with Google to back up "About you" (core/account.dart), or the signed-in account with sign-out
/// and account deletion.
class GoogleBackupCard extends ConsumerStatefulWidget {
  const GoogleBackupCard({super.key});
  @override
  ConsumerState<GoogleBackupCard> createState() => _GoogleBackupCardState();
}

class _GoogleBackupCardState extends ConsumerState<GoogleBackupCard> {
  bool _busy = false;

  Future<void> _signIn() async {
    final lang = ref.read(prefsProvider).language;
    setState(() => _busy = true);
    String? message;
    try {
      final restored = await Account.signIn(ref.read(aboutYouProvider));
      if (restored != null) {
        await ref.read(aboutYouProvider.notifier).restore(restored);
        unawaited(refreshCalendarReminders(ref));
        message = t3(
          lang,
          'Signed in. Your details were restored from your backup.',
          'साइन इन हो गया। आपका विवरण बैकअप से वापस आ गया।',
          'సైన్ ఇన్ అయ్యారు. మీ వివరాలు బ్యాకప్ నుంచి తిరిగి వచ్చాయి.',
        );
      } else {
        message = t3(
          lang,
          'Signed in. Your details are backed up.',
          'साइन इन हो गया। आपके विवरण का बैकअप है।',
          'సైన్ ఇన్ అయ్యారు. మీ వివరాలు బ్యాకప్ అయ్యాయి.',
        );
      }
      Usage.record('account_sign_in');
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        message = t3(
          lang,
          'Google sign-in did not work. Try again.',
          'Google साइन-इन नहीं हुआ। फिर कोशिश करें।',
          'Google సైన్ ఇన్ కాలేదు. మళ్ళీ ప్రయత్నించండి.',
        );
      }
    } catch (e) {
      debugPrint('Account sign-in failed: $e');
      message = t3(
        lang,
        'Could not sign in. Check your connection and try again.',
        'साइन इन नहीं हो सका। कनेक्शन जाँचकर फिर कोशिश करें।',
        'సైన్ ఇన్ కాలేదు. కనెక్షన్ చూసి మళ్ళీ ప్రయత్నించండి.',
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) toast(context, message);
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await Account.signOut();
    } catch (e) {
      debugPrint('Account sign-out failed: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final lang = ref.read(prefsProvider).language;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
        title: Text(t3(lang, 'Delete your account?', 'अपना खाता हटाएँ?', 'మీ ఖాతా తొలగించాలా?')),
        content: Text(
          t3(
            lang,
            'This deletes your Devalay account, your backup, your usage statistics and your chats with the developer. It cannot be undone. Your details stay on this phone until you remove them.',
            'इससे आपका देवालय खाता, बैकअप, उपयोग के आँकड़े और डेवलपर से चैट हट जाएँगे। यह वापस नहीं होगा। आपका विवरण इस फ़ोन पर तब तक रहेगा जब तक आप उसे न हटाएँ।',
            'దీనితో మీ దేవాలయం ఖాతా, బ్యాకప్, వినియోగ గణాంకాలు, డెవలపర్‌తో చాట్‌లు తొలగిపోతాయి. దీన్ని వెనక్కి తీసుకోలేం. మీరు తొలగించే వరకు మీ వివరాలు ఈ ఫోన్‌లోనే ఉంటాయి.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t3(lang, 'Cancel', 'रद्द करें', 'రద్దు')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t3(lang, 'Delete account', 'खाता हटाएँ', 'ఖాతా తొలగించండి')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    String message;
    try {
      await Account.deleteAccount();
      message = t3(lang, 'Your account was deleted.', 'आपका खाता हटा दिया गया।', 'మీ ఖాతా తొలగించబడింది.');
    } on GoogleSignInException catch (_) {
      message = t3(
        lang,
        'Sign in again with Google to delete your account.',
        'खाता हटाने के लिए Google से फिर साइन इन करें।',
        'ఖాతా తొలగించడానికి Google తో మళ్ళీ సైన్ ఇన్ చేయండి.',
      );
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      message = t3(
        lang,
        'Could not delete the account. Check your connection and try again.',
        'खाता नहीं हट सका। कनेक्शन जाँचकर फिर कोशिश करें।',
        'ఖాతా తొలగించలేకపోయాం. కనెక్షన్ చూసి మళ్ళీ ప్రయత్నించండి.',
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    toast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final User? user = ref.watch(accountProvider).value;
    final scheme = Theme.of(context).colorScheme;
    if (user == null) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          leading: Icon(Icons.cloud_upload_rounded, color: scheme.primary),
          title: Text(
            t3(lang, 'Back up with Google', 'Google से बैकअप लें', 'Google తో బ్యాకప్'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            t3(
              lang,
              'Optional. Sign in to keep your details when you reinstall or change phones.',
              'वैकल्पिक। ऐप दोबारा इंस्टॉल करने या फ़ोन बदलने पर भी विवरण बना रहे, इसके लिए साइन इन करें।',
              'ఐచ్ఛికం. యాప్ మళ్ళీ ఇన్‌స్టాల్ చేసినా, ఫోన్ మార్చినా మీ వివరాలు ఉండాలంటే సైన్ ఇన్ చేయండి.',
            ),
          ),
          trailing: _busy
              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Icon(Icons.login_rounded),
          onTap: _busy ? null : _signIn,
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.verified_user_rounded, color: scheme.primary),
            title: Text(user.email ?? user.displayName ?? 'Google'),
            subtitle: Text(
              t3(
                lang,
                'Signed in with Google · your details are backed up',
                'Google से साइन इन · आपके विवरण का बैकअप है',
                'Google తో సైన్ ఇన్ · మీ వివరాలు బ్యాకప్ అయ్యాయి',
              ),
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: Text(t3(lang, 'Sign out', 'साइन आउट', 'సైన్ అవుట్')),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_forever_rounded),
                label: Text(t3(lang, 'Delete account', 'खाता हटाएँ', 'ఖాతా తొలగించండి')),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Opens "About you".
void openProfile(BuildContext context) => context.push('/profile');
