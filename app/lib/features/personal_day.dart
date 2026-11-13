import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/glossary.dart';
import '../core/i18n.dart';
import '../core/muhurta.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import 'muhurta_view.dart';

/// "Is today good for me?": Tarabalam from the birth star and Chandrabalam from the moon sign.
class PersonalBalam extends ConsumerWidget {
  const PersonalBalam({super.key, required this.data});

  /// The day's panchang (nakshatra list and moon_rashi).
  final Map data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final lang = prefs.language;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final star = prefs.birthStar;
    final rashi = prefs.rashi == null ? -1 : rashiNames.indexWhere((r) => r.toLowerCase() == prefs.rashi);

    if (star == null) {
      return Card(
        margin: const EdgeInsets.only(top: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          onTap: () => showBirthStarPicker(context, ref),
          leading: const Text('🌟', style: TextStyle(fontSize: 28)),
          title: Text(
            t3(lang, 'Is today good for you?', 'क्या आज आपके लिए शुभ है?', 'ఈ రోజు మీకు మంచిదేనా?'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            t3(
              lang,
              'Add your birth star to see your Tarabalam and Chandrabalam every day.',
              'हर दिन अपना तारा बल और चंद्र बल देखने के लिए जन्म नक्षत्र जोड़ें।',
              'ప్రతి రోజు మీ తారాబలం, చంద్రబలం చూడటానికి జన్మ నక్షత్రం జోడించండి.',
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: scheme.primary),
        ),
      );
    }

    final stars = (data['nakshatra'] as List?)?.cast<Map>() ?? const <Map>[];
    final today = stars.isEmpty ? -1 : (stars.first['index'] as int) - 1;
    final moon = rashiNames.indexOf('${data['moon_rashi']}');
    if (today < 0) return const SizedBox.shrink();
    final tara = tarabalam(star, today);
    final chandra = rashi >= 0 && moon >= 0 ? chandrabalam(rashi, moon) : null;

    Color tone(Quality q) => qualityColor(q, dark: dark, neutral: scheme.outline);
    final good = tara.quality != Quality.bad && (chandra == null || chandra.quality == Quality.good);
    final bad = tara.quality == Quality.bad && (chandra == null || chandra.quality == Quality.bad);
    final verdict = good
        ? t3(lang, 'A good day for you', 'आपके लिए शुभ दिन', 'మీకు మంచి రోజు')
        : bad
        ? t3(lang, 'Better to postpone big beginnings', 'बड़े आरंभ टालना बेहतर', 'పెద్ద ప్రారంభాలు వాయిదా వేయడం మంచిది')
        : t3(
            lang,
            'A mixed day: plan big things with care',
            'मिला-जुला दिन: बड़े काम सोचकर करें',
            'మిశ్రమ రోజు: పెద్ద పనులు జాగ్రత్తగా',
          );

    Widget row(String term, String label, String value, Quality q) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          MeaningButton(term, lang: lang),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, color: tone(q)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: tone(q).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Text(
              qualityLabel(lang, q),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tone(q)),
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin_circle_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      t3(lang, 'For you', 'आपके लिए', 'మీ కోసం'),
                      nakshatraLabel(lang, star),
                      if (rashi >= 0) rashiLabel(lang, rashi),
                    ].join(' · '),
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: t3(lang, 'Change', 'बदलें', 'మార్చు'),
                  onPressed: () => showBirthStarPicker(context, ref),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  row(
                    'tarabalam',
                    t3(lang, 'Tarabalam', 'तारा बल', 'తారాబలం'),
                    taraLabel(lang, tara.key),
                    tara.quality,
                  ),
                  if (chandra != null)
                    row(
                      'chandrabalam',
                      t3(lang, 'Chandrabalam', 'चंद्र बल', 'చంద్రబలం'),
                      '${ordinal(lang, chandra.house)} ${t3(lang, 'house', 'भाव', 'స్థానం')}',
                      chandra.quality,
                    ),
                  const SizedBox(height: 6),
                  Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: good ? const LinearGradient(colors: Palette.sunrise) : null,
                          color: good ? null : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${good ? '🌟 ' : ''}$verdict',
                          style: TextStyle(fontWeight: FontWeight.w700, color: good ? Colors.white : null),
                        ),
                      )
                      .animate(onPlay: good ? (c) => c.repeat() : null)
                      .shimmer(duration: 2600.ms, delay: 800.ms, color: good ? Colors.white38 : Colors.transparent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user set their birth nakshatra and moon sign (shared with Rashifal).
Future<void> showBirthStarPicker(BuildContext context, WidgetRef ref) => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _BirthStarSheet(),
);

class _BirthStarSheet extends ConsumerStatefulWidget {
  const _BirthStarSheet();
  @override
  ConsumerState<_BirthStarSheet> createState() => _BirthStarSheetState();
}

class _BirthStarSheetState extends ConsumerState<_BirthStarSheet> {
  late int? _star = ref.read(prefsProvider).birthStar;
  late int? _rashi = () {
    final r = ref.read(prefsProvider).rashi;
    final i = r == null ? -1 : rashiNames.indexWhere((n) => n.toLowerCase() == r);
    return i < 0 ? null : i;
  }();

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t3(lang, 'My birth star', 'मेरा जन्म नक्षत्र', 'నా జన్మ నక్షత్రం'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t3(
              lang,
              'From your horoscope (jatakam). Kept on this phone only.',
              'अपनी जन्म कुंडली से। केवल इसी फ़ोन पर रहता है।',
              'మీ జాతకం నుంచి. ఈ ఫోన్‌లో మాత్రమే ఉంటుంది.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _star,
            isExpanded: true,
            decoration: InputDecoration(labelText: t3(lang, 'Nakshatra', 'नक्षत्र', 'నక్షత్రం')),
            items: [for (var i = 0; i < 27; i++) DropdownMenuItem(value: i, child: Text(nakshatraLabel(lang, i)))],
            onChanged: (v) => setState(() {
              _star = v;
              if (v != null) _rashi = rashiOfStar(v);
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(_rashi),
            initialValue: _rashi,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: t3(lang, 'Rashi (moon sign)', 'राशि (चंद्र राशि)', 'రాశి (చంద్ర రాశి)'),
            ),
            items: [for (var i = 0; i < 12; i++) DropdownMenuItem(value: i, child: Text(rashiLabel(lang, i)))],
            onChanged: (v) => setState(() => _rashi = v),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _star == null
                ? null
                : () async {
                    final n = ref.read(prefsProvider.notifier);
                    await n.set('birth_star', _star);
                    if (_rashi != null) await n.setRashi(rashiNames[_rashi!].toLowerCase());
                    if (context.mounted) Navigator.pop(context);
                  },
            icon: const Icon(Icons.check_rounded),
            label: Text(t3(lang, 'Save', 'सहेजें', 'సేవ్')),
          ),
        ],
      ),
    );
  }
}
