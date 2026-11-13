import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n.dart';
import '../core/languages.dart';
import '../widgets/language_picker.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../widgets/mandala.dart';

const _deities = [
  ('venkateswara', 'Venkateswara', 'वेंकटेश्वर', '🙏'),
  ('shiva', 'Mahadev', 'महादेव', '🔱'),
  ('hanuman', 'Hanuman', 'हनुमान', '🚩'),
  ('rama', 'Shri Ram', 'श्री राम', '🏹'),
  ('krishna', 'Krishna', 'कृष्ण', '🪈'),
  ('ganesha', 'Ganesha', 'गणेश', '🐘'),
  ('durga', 'Maa Durga', 'माँ दुर्गा', '🦁'),
  ('lakshmi', 'Lakshmi', 'लक्ष्मी', '🪷'),
  ('vishnu', 'Vishnu', 'विष्णु', '🐚'),
  ('saraswati', 'Saraswati', 'सरस्वती', '🎼'),
  ('shani', 'Shani Dev', 'शनि देव', '🪐'),
  ('surya', 'Surya', 'सूर्य', '☀️'),
  ('kali', 'Maa Kali', 'माँ काली', '🌺'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  void _next() {
    if (_index == 3) {
      _finish();
    } else {
      _page.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    await ref.read(prefsProvider.notifier).completeOnboarding();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final lang = prefs.language;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3E0E05), Palette.maroon, Color(0xFF9A3412)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [
                      _Welcome(lang: lang),
                      _LanguagePage(lang: lang),
                      _DeityPage(lang: lang),
                      _CityRashiPage(lang: lang),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? Palette.gold : Colors.white30,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      const Spacer(),
                      if (_index > 0)
                        TextButton(
                          onPressed: _finish,
                          child: Text(
                            t3(lang, 'Skip', 'छोड़ें', 'దాటవేయండి'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.maroon),
                        onPressed: _next,
                        child: Text(
                          _index == 3
                              ? (t3(lang, 'Begin 🙏', 'आरंभ करें 🙏', 'ప్రారంభించండి 🙏'))
                              : (t3(lang, 'Next', 'आगे', 'తర్వాత')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.lang});
  final String lang;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const Mandala(size: 300, color: Palette.gold, opacity: 0.35),
            const Text(
              'ॐ',
              style: TextStyle(fontSize: 110, color: Palette.gold, fontFamily: scriptureFont),
            ).animate().fadeIn(duration: 900.ms).scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          appNameIn(lang),
          style: const TextStyle(fontSize: 44, color: Colors.white, fontWeight: FontWeight.w700),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
        const Text('Devalay', style: TextStyle(fontSize: 18, color: Colors.white70, letterSpacing: 6)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            t3(
              lang,
              'Aarti, bhajans, mantras, the Gita, Panchang and your own Mandir. Free, ad-free and private.',
              'आरती, भजन, मंत्र, गीता, पंचांग और आपका अपना मंदिर। निःशुल्क, विज्ञापन-रहित और निजी।',
              'హారతులు, భజనలు, మంత్రాలు, భగవద్గీత, పంచాంగం, మీ సొంత మందిరం. ఉచితం, ప్రకటనలు లేవు, మీ సమాచారం మీ దగ్గరే.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
        ).animate().fadeIn(delay: 600.ms),
      ],
    );
  }
}

class _LanguagePage extends ConsumerWidget {
  const _LanguagePage({required this.lang});
  final String lang;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider).language;
    return _Page(
      title: t3(lang, 'Choose your language', 'भाषा चुनें', 'మీ భాషను ఎంచుకోండి'),
      subtitle: languageOf(lang).greeting,
      children: const [LanguageGrid(onDark: true)],
    );
  }
}

class _DeityPage extends ConsumerWidget {
  const _DeityPage({required this.lang});
  final String lang;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ishta = ref.watch(prefsProvider).ishtaDevta;
    return _Page(
      title: t3(lang, 'Your Ishta Devta', 'आपके इष्ट देव', 'మీ ఇష్ట దైవం'),
      subtitle: t3(
        lang,
        'Your Mandir and home screen will be dedicated to them',
        'आपका मंदिर और होम स्क्रीन इन्हीं से सजेगा',
        'మీ మందిరం, హోమ్ స్క్రీన్ ఈ దైవానికి అంకితం',
      ),
      children: [
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final (slug, en, hiName, emoji) in _deities)
              _Choice(
                selected: ishta == slug,
                onTap: () => ref.read(prefsProvider.notifier).setIshta(slug),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 4),
                    Text(
                      pickLang(lang, en, hiName, te: teluguDeities[slug]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CityRashiPage extends ConsumerWidget {
  const _CityRashiPage({required this.lang});
  final String lang;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final dropdownStyle = const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Mukta');
    return _Page(
      title: t3(lang, 'Panchang & Rashi', 'पंचांग और राशि', 'పంచాంగం & రాశి'),
      subtitle: t3(
        lang,
        'Sunrise and muhurta timings for your city. No GPS needed.',
        'सूर्योदय और मुहूर्त आपके शहर के अनुसार। GPS की आवश्यकता नहीं।',
        'మీ నగరానికి సూర్యోదయం, ముహూర్త సమయాలు. GPS అవసరం లేదు.',
      ),
      children: [
        _Choice(
          selected: true,
          onTap: () {},
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: prefs.cityId,
              dropdownColor: Palette.maroon,
              style: dropdownStyle,
              iconEnabledColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              items: [for (final c in cities) DropdownMenuItem(value: c.id, child: Text(c.label(lang)))],
              onChanged: (v) => ref.read(prefsProvider.notifier).setCity(v!),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t3(lang, 'Your Moon sign (optional)', 'आपकी चंद्र राशि (वैकल्पिक)', 'మీ చంద్ర రాశి (ఐచ్ఛికం)'),
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        // Chips paint on a Material that defaults to the light canvas colour, which showed through
        // the translucent chip background; a transparent canvas lets the dark page show instead.
        Theme(
          data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (slug, en, hiName, symbol) in rashiList)
                ChoiceChip(
                  label: Text('$symbol ${pickLang(lang, en, hiName, te: teluguRashiBySlug[slug])}'),
                  selected: prefs.rashi == slug,
                  showCheckmark: false,
                  color: WidgetStatePropertyAll(
                    prefs.rashi == slug ? Palette.gold : Colors.white.withValues(alpha: 0.08),
                  ),
                  side: BorderSide(color: prefs.rashi == slug ? Palette.gold : Colors.white24),
                  labelStyle: TextStyle(
                    color: prefs.rashi == slug ? Palette.maroon : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => ref.read(prefsProvider.notifier).setRashi(slug),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: prefs.dailyReminder,
          activeThumbColor: Palette.gold,
          title: Text(
            t3(
              lang,
              'Morning prayer reminder (6:30 AM)',
              'सुबह प्रार्थना याद दिलाएँ (6:30)',
              'ఉదయం పూజ రిమైండర్ (6:30)',
            ),
            style: const TextStyle(color: Colors.white),
          ),
          onChanged: (v) async {
            if (v && !await Notifications.requestPermission()) return;
            await ref.read(prefsProvider.notifier).set('daily_reminder', v);
            v ? await Notifications.scheduleDaily(6, 30, lang: prefs.language) : await Notifications.cancelDaily();
          },
        ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
      ],
      const SizedBox(height: 24),
      ...children,
    ].animate(interval: 60.ms).fadeIn().slideX(begin: 0.08),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    decoration: BoxDecoration(
      color: selected ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
      border: Border.all(color: selected ? Palette.gold : Colors.white24, width: selected ? 2 : 1),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: child),
    ),
  );
}
