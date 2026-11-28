import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_care.dart';
import '../core/auth.dart';
import '../core/billing.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/sharing.dart';
import '../widgets/common.dart';
import 'support.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final tiles = [
      ('🔮', 'rashifal', '/rashifal', Palette.dusk),
      ('📅', 'calendar', '/calendar', Palette.sunrise),
      ('🌞', 'today_panchang', '/panchang', const [Color(0xFFF57F17), Color(0xFFE65100)]),
      ('🗓️', 'important_days', '/calendar/important', const [Color(0xFFAD1457), Color(0xFFE65100)]),
      ('🎂', 'my_events', '/calendar/events', const [Color(0xFF1565C0), Color(0xFF7B1FA2)]),
      ('💍', 'matching', '/matching', const [Color(0xFFAD1457), Color(0xFFF06292)]),
      ('🌸', 'muhurtham', '/muhurtham', const [Color(0xFF2E7D32), Color(0xFFF9A825)]),
      ('📜', 'jatakam', '/jatakam', const [Color(0xFF4527A0), Color(0xFFAD1457)]),
      ('🪔', 'pooja_guides', '/pooja', const [Color(0xFFBF360C), Color(0xFFFFA000)]),
      ('📿', 'japa', '/japa', const [Color(0xFF4E342E), Color(0xFF8D6E63)]),
      ('✨', 'ai_status', '/status', const [Color(0xFF6A1B9A), Color(0xFFD81B60)]),
      ('🖼️', 'wallpapers', '/wallpapers', Palette.sky),
      ('🔔', 'ringtones', '/ringtones', Palette.tulsi),
      ('🎬', 'movies', '/videos', const [Color(0xFF263238), Color(0xFF546E7A)]),
      ('🙋', 'ask_gita', '/ask', const [Color(0xFF0D47A1), Color(0xFF4A148C)]),
      ('❤️', 'favorites', '/favorites', const [Color(0xFFC62828), Color(0xFFEF5350)]),
      ('⬇️', 'downloads', '/downloads', const [Color(0xFF00695C), Color(0xFF26A69A)]),
      ('⚙️', 'settings', '/settings', const [Color(0xFF424242), Color(0xFF757575)]),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'more'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24).withSystemInsets(context),
        children: [
          // Static (serverless) builds have no accounts; Premium comes from Google Play in every build.
          if (!AppConfig.staticApi) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: const CircleAvatar(radius: 26, child: Text('🙏', style: TextStyle(fontSize: 24))),
                title: Text(
                  auth.signedIn
                      ? (auth.user!.displayName.isNotEmpty ? auth.user!.displayName : auth.user!.email)
                      : l3(
                          ref,
                          'Sign in to sync favourites',
                          'पसंदीदा सिंक करने के लिए साइन इन करें',
                          'ఇష్టమైనవి సింక్ చేయడానికి సైన్ ఇన్ చేయండి',
                        ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  auth.signedIn
                      ? (auth.isPremium ? 'Premium 👑' : 'Free plan')
                      : l3(
                          ref,
                          'Optional. Everything works without an account.',
                          'वैकल्पिक। बिना खाते के भी सब चलता है।',
                          'ఐచ్ఛికం. ఖాతా లేకపోయినా అన్నీ పనిచేస్తాయి.',
                        ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(auth.signedIn ? '/settings' : '/login'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const _PremiumCard(),
          const SizedBox(height: 16),
          GradientCard(
            colors: const [Color(0xFFFF8F00), Color(0xFFE65100), Color(0xFF8E1B1B)],
            padding: 16,
            onTap: () => context.push('/temples'),
            child: Row(
              children: [
                const Text('🎟️', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(ref, 'temple_booking'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        l3(
                          ref,
                          'TTD darshan tickets, sevas, rooms and more temples',
                          'टीटीडी दर्शन टिकट, सेवा, कमरे और अन्य मंदिर',
                          'టీటీడీ దర్శన టికెట్లు, సేవలు, గదులు, మరిన్ని ఆలయాలు',
                        ),
                        style: const TextStyle(color: Colors.white70, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GradientCard(
            colors: const [Color(0xFF880E4F), Color(0xFFC2185B), Color(0xFFFF8F00)],
            padding: 16,
            onTap: () => context.push('/wishes'),
            child: Row(
              children: [
                const Text('💌', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(ref, 'wishes'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        l3(
                          ref,
                          'Cards with your photo and name for every festival and every morning',
                          'हर त्योहार और हर सुबह के लिए आपकी फ़ोटो और नाम वाले कार्ड',
                          'ప్రతి పండుగకు, ప్రతి ఉదయానికి మీ ఫోటో, పేరుతో కార్డులు',
                        ),
                        style: const TextStyle(color: Colors.white70, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final (i, (emoji, key, route, colors)) in tiles.indexed)
                GradientCard(
                  colors: colors,
                  padding: 10,
                  radius: 20,
                  onTap: () => context.push(route),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 6),
                      TileLabel(
                        tr(ref, key),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (30 * i).ms).scale(begin: const Offset(0.92, 0.92)),
            ],
          ),
          const SizedBox(height: 16),
          const RateCard(),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Text('🙏', style: TextStyle(fontSize: 26)),
              title: Text(
                l3(ref, 'Support Devalay', 'देवालय का साथ दें', 'దేవాలయంకు అండగా నిలవండి'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                l3(
                  ref,
                  'A small gift to the developer, or give to a temple',
                  'डेवलपर को छोटा सा उपहार, या मंदिर को दान',
                  'డెవలపర్‌కు చిన్న కానుక, లేదా ఆలయానికి విరాళం',
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/support?from=more'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium: an invitation for free users, a thank-you badge for members.
class _PremiumCard extends ConsumerWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    return GradientCard(
      colors: const [Color(0xFFFFB300), Color(0xFFE65100)],
      padding: 16,
      onTap: () => context.push('/premium?from=more'),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premium
                      ? t3(lang, 'Premium member', 'प्रीमियम सदस्य', 'ప్రీమియం సభ్యులు')
                      : t3(lang, 'Devalay Premium', 'देवालय प्रीमियम', 'దేవాలయం ప్రీమియం'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  premium
                      ? t3(
                          lang,
                          'Thank you for keeping Devalay free for every devotee 🙏',
                          'देवालय को हर भक्त के लिए मुफ़्त रखने के लिए धन्यवाद 🙏',
                          'దేవాలయంను ప్రతి భక్తునికీ ఉచితంగా ఉంచుతున్నందుకు ధన్యవాదాలు 🙏',
                        )
                      : premiumPitch(lang),
                  style: const TextStyle(color: Colors.white, height: 1.25),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

/// "Enjoying Devalay?": rate on Play, share with family, or send feedback.
class RateCard extends ConsumerWidget {
  const RateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
    return GradientCard(
      colors: Palette.dusk,
      padding: 16,
      onTap: rateApp,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t3(lang, 'Enjoying Devalay?', 'देवालय पसंद आ रहा है?', 'దేవాలయం నచ్చిందా?'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t3(
                        lang,
                        'A rating on Google Play helps other families find it. It is free and has no ads, thanks to you.',
                        'Google Play पर रेटिंग से दूसरे परिवार इसे खोज पाते हैं। यह मुफ़्त और विज्ञापन-रहित है।',
                        'Google Playలో మీ రేటింగ్ ఇతర కుటుంబాలకు ఈ యాప్‌ను చూపిస్తుంది. ఇది ఉచితం, ప్రకటనలు లేవు.',
                      ),
                      style: const TextStyle(color: Colors.white70, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                const Icon(Icons.star_rounded, color: Palette.gold, size: 34)
                    .animate(delay: (120 * i).ms)
                    .scale(begin: const Offset(0.3, 0.3), curve: Curves.easeOutBack, duration: 400.ms),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              action(
                Icons.star_rate_rounded,
                t3(lang, 'Rate on Play', 'Play पर रेट करें', 'Playలో రేట్ చేయండి'),
                rateApp,
              ),
              action(
                Icons.share_rounded,
                t3(lang, 'Share with family', 'परिवार से साझा करें', 'కుటుంబంతో పంచుకోండి'),
                () => shareApp(lang),
              ),
              action(
                Icons.feedback_rounded,
                t3(lang, 'Send feedback', 'सुझाव भेजें', 'సూచనలు పంపండి'),
                () => context.push('/feedback'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }
}
