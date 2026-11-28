import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/about_you.dart';
import '../core/i18n.dart';
import '../core/muhurta.dart';
import '../core/nakshatra_info.dart';
import '../core/providers.dart';
import '../core/script.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import 'personal_day.dart';

/// "Your day": everything personal about today in one place. Tarabalam and Chandrabalam, the day's good
/// and avoid times with what is in force now, the reading for the user's rashi (love, work, health,
/// remedy, lucky colour and number), their birth star's deity, planet and mantra, a Janma Nakshatra
/// note, the birthday countdown, and a personal status to share.
class ForYouScreen extends ConsumerWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final prefs = ref.watch(prefsProvider);
    final me = ref.watch(aboutYouProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final day = ref.watch(panchangProvider(today));
    final star = prefs.birthStar;
    final rashi = prefs.rashi == null ? -1 : rashiNames.indexWhere((r) => r.toLowerCase() == prefs.rashi);
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Your day', 'आपका दिन', 'మీ రోజు'))),
      body: day.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(panchangProvider(today))),
        data: (data) {
          final todayStar = _starNow(data);
          final janma = star != null && todayStar != null && todayStar - 1 == star;
          final next = me.nextBirthday(today);
          final days = next?.difference(today).inDays;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24).withSystemInsets(context),
            children: [
              _Greeting(name: me.firstName, star: star, rashi: rashi),
              if (star == null)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  child: ListTile(
                    leading: const Text('🌟', style: TextStyle(fontSize: 28)),
                    title: Text(
                      t3(
                        lang,
                        'Add your birth star for a personal day',
                        'व्यक्तिगत दिन के लिए जन्म नक्षत्र जोड़ें',
                        'మీ రోజు కోసం జన్మ నక్షత్రం జోడించండి',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/profile'),
                  ),
                )
              else
                PersonalBalam(data: data, showMore: false),
              if (janma)
                _Note(
                  emoji: '🪔',
                  text: t3(
                    lang,
                    'Today is your Janma Nakshatra: a good day for a pooja, an archana in your name, or a visit to the temple.',
                    'आज आपका जन्म नक्षत्र है: पूजा, अपने नाम से अर्चना या मंदिर दर्शन के लिए अच्छा दिन।',
                    'ఈ రోజు మీ జన్మ నక్షత్రం: పూజ, మీ పేరున అర్చన లేదా ఆలయ దర్శనానికి మంచి రోజు.',
                  ),
                ),
              if (days != null && days <= 45)
                _Note(
                  emoji: '🎂',
                  text: days == 0
                      ? t3(lang, 'Happy birthday! 🙏', 'जन्मदिन मुबारक! 🙏', 'పుట్టినరోజు శుభాకాంక్షలు! 🙏')
                      : t3(
                          lang,
                          'Your birthday is in $days days.',
                          'आपका जन्मदिन $days दिन में है।',
                          'మీ పుట్టినరోజు $days రోజుల్లో.',
                        ),
                ),
              _Times(data: data),
              if (rashi >= 0) _RashiToday(rashi: rashi),
              if (star != null) _BirthStar(star: star),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Usage.record('for_you_status');
                  context.push('/status');
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  t3(lang, 'Make my status for today', 'आज का मेरा स्टेटस बनाएँ', 'ఈ రోజు నా స్టేటస్ తయారు చేయండి'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The nakshatra (API index 1-27) in force now, or at sunrise.
int? _starNow(Map data) {
  final stars = daySpans(data['nakshatra']).where((s) => s.index >= 1 && s.index <= 27).toList();
  if (stars.isEmpty) return null;
  final sunrise = '${data['sunrise'] ?? ''}';
  return stars[spanAt(stars, sunrise.isEmpty ? null : nowIn(sunrise))].index;
}

class _Greeting extends ConsumerWidget {
  const _Greeting({required this.name, required this.star, required this.rashi});
  final String name;
  final int? star;
  final int rashi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final hour = DateTime.now().hour;
    final hello = hour < 12
        ? t3(lang, 'Good morning', 'सुप्रभात', 'శుభోదయం')
        : hour < 17
        ? t3(lang, 'Good afternoon', 'नमस्कार', 'నమస్కారం')
        : t3(lang, 'Good evening', 'शुभ संध्या', 'శుభ సాయంత్రం');
    return GradientCard(
      colors: const [Color(0xFF4A148C), Color(0xFFC2185B), Color(0xFFFF8F00)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? hello : '$hello, $name',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (star != null)
            Text(
              [nakshatraLabel(lang, star!), if (rashi >= 0) rashiLabel(lang, rashi)].join(' · '),
              style: const TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.emoji, required this.text});
  final String emoji, text;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 28)),
      title: Text(text),
    ),
  );
}

/// Good times and times to avoid, each with its clock times; the one in force now is marked.
class _Times extends ConsumerWidget {
  const _Times({required this.data});
  final Map data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final sunrise = '${data['sunrise'] ?? ''}';
    if (sunrise.isEmpty) return const SizedBox.shrink();
    final now = nowIn(sunrise);
    List<({String starts, String ends})> spans(Object? v) => [
      if (v is Map && v['starts'] != null && v['ends'] != null) (starts: '${v['starts']}', ends: '${v['ends']}'),
      if (v is List)
        for (final m in v.whereType<Map>())
          if (m['starts'] != null && m['ends'] != null) (starts: '${m['starts']}', ends: '${m['ends']}'),
    ];
    final good = [
      ('brahma_muhurta', t3(lang, 'Brahma Muhurta', 'ब्रह्म मुहूर्त', 'బ్రహ్మ ముహూర్తం')),
      ('abhijit_muhurta', t3(lang, 'Abhijit Muhurta', 'अभिजित मुहूर्त', 'అభిజిత్ ముహూర్తం')),
      ('amrit_kalam', t3(lang, 'Amrit Kalam', 'अमृत काल', 'అమృత కాలం')),
    ];
    final avoid = [
      ('rahu_kaal', t3(lang, 'Rahu Kalam', 'राहु काल', 'రాహు కాలం')),
      ('yamaganda', t3(lang, 'Yamagandam', 'यमगंड', 'యమగండం')),
      ('gulika_kaal', t3(lang, 'Gulika Kalam', 'गुलिक काल', 'గుళిక కాలం')),
      ('durmuhurtham', t3(lang, 'Durmuhurtam', 'दुर्मुहूर्त', 'దుర్ముహూర్తం')),
      ('varjyam', t3(lang, 'Varjyam', 'वर्ज्यम्', 'వర్జ్యం')),
    ];
    final today = '${data['date'] ?? ''}';

    Widget row(String label, ({String starts, String ends}) s, bool isGood) {
      final a = wallClock(s.starts), b = wallClock(s.ends);
      final on = !now.isBefore(a) && now.isBefore(b);
      final otherDay = today.isNotEmpty && !s.starts.startsWith(today);
      final color = isGood ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(isGood ? Icons.check_circle_rounded : Icons.do_not_disturb_on_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(
              '${clock(a)} – ${clock(b)}${otherDay ? ' (+1)' : ''}',
              style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w500, color: on ? color : null),
            ),
            if (on)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  t3(lang, 'NOW', 'अभी', 'ఇప్పుడు'),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t3(lang, 'Your times today', 'आज आपके समय', 'ఈ రోజు మీ సమయాలు'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final (key, label) in good)
              for (final s in spans(data[key])) row(label, s, true),
            const Divider(),
            for (final (key, label) in avoid)
              for (final s in spans(data[key])) row(label, s, false),
          ],
        ),
      ),
    );
  }
}

/// Today's reading for the user's moon sign.
class _RashiToday extends ConsumerWidget {
  const _RashiToday({required this.rashi});
  final int rashi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final readings = ref.watch(rashifalProvider).value;
    final r = readings?.where((m) => '${m['rashi']}' == rashiNames[rashi].toLowerCase()).firstOrNull;
    if (r == null) return const SizedBox.shrink();
    final rating = (r['rating'] as num?)?.toInt() ?? 3;
    Widget line(String emoji, String title, Object? text) => text == null || '$text'.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$title  ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: '$text'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${r['symbol'] ?? ''} ', style: const TextStyle(fontSize: 22)),
                Expanded(
                  child: Text(
                    '${rashiLabel(lang, rashi)} · ${t3(lang, 'today', 'आज', 'ఈ రోజు')}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: Palette.marigold,
                  ),
              ],
            ),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('${r['overview'] ?? ''}')),
            line('💞', t3(lang, 'Love', 'प्रेम', 'ప్రేమ'), r['love']),
            line('💼', t3(lang, 'Work', 'काम', 'పని'), r['career']),
            line('🌿', t3(lang, 'Health', 'स्वास्थ्य', 'ఆరోగ్యం'), r['health']),
            line('🪔', t3(lang, 'Remedy', 'उपाय', 'పరిహారం'), r['remedy']),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r['lucky_color'] != null)
                  Chip(
                    avatar: const Icon(Icons.palette_rounded, size: 16),
                    label: Text('${t3(lang, 'Lucky colour', 'शुभ रंग', 'అదృష్ట రంగు')}: ${r['lucky_color']}'),
                  ),
                if (r['lucky_number'] != null)
                  Chip(
                    avatar: const Icon(Icons.tag_rounded, size: 16),
                    label: Text('${t3(lang, 'Lucky number', 'शुभ अंक', 'అదృష్ట సంఖ్య')}: ${r['lucky_number']}'),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/rashifal'),
                child: Text(t3(lang, 'Week, month and year', 'सप्ताह, महीना और वर्ष', 'వారం, నెల, సంవత్సరం')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The birth star's deity, ruling planet, symbol and gana, and the planet's mantra to chant.
class _BirthStar extends ConsumerWidget {
  const _BirthStar({required this.star});
  final int star;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final info = nakshatraInfo[star];
    final mantra = lang == 'hi' || lang == 'mr'
        ? info.lord.mantra
        : toIndicScript(lang == 'en' ? 'hi' : lang, info.lord.mantra);
    Widget fact(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t3(lang, 'Your birth star', 'आपका जन्म नक्षत्र', 'మీ జన్మ నక్షత్రం')}: ${nakshatraLabel(lang, star)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            fact(t3(lang, 'Deity', 'देवता', 'అధిదేవత'), tri(info.deity, lang)),
            fact(t3(lang, 'Ruling planet', 'स्वामी ग्रह', 'అధిపతి గ్రహం'), tri(info.lord.name, lang)),
            fact(t3(lang, 'Symbol', 'प्रतीक', 'చిహ్నం'), tri(info.symbol, lang)),
            fact(t3(lang, 'Gana', 'गण', 'గణం'), tri(info.gana.name, lang)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    t3(lang, 'Your mantra', 'आपका मंत्र', 'మీ మంత్రం'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    mantra,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: scriptureFont,
                      fontFamilyFallback: scriptureFontFallback,
                      fontSize: 22,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: mantra));
                      Usage.record('for_you_mantra', item: info.lord.name.$1);
                      toast(context, t3(lang, 'Copied', 'कॉपी हो गया', 'కాపీ అయింది'));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(t3(lang, 'Chant 108 times today', 'आज 108 बार जपें', 'ఈ రోజు 108 సార్లు జపించండి')),
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
