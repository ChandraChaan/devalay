import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final tiles = [
      ('🔮', 'rashifal', '/rashifal', Palette.dusk),
      ('📅', 'calendar', '/calendar', Palette.sunrise),
      ('🌞', 'today_panchang', '/panchang', const [Color(0xFFF57F17), Color(0xFFE65100)]),
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          // Static (serverless) builds have no accounts or billing.
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
                      : pick(
                          ref,
                          'Optional. Everything works without an account.',
                          'वैकल्पिक। बिना खाते के भी सब चलता है।',
                        ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(auth.signedIn ? '/settings' : '/login'),
              ),
            ),
            const SizedBox(height: 12),
            if (!auth.isPremium)
              GradientCard(
                colors: const [Color(0xFFFFB300), Color(0xFFE65100)],
                padding: 16,
                onTap: () => context.push('/premium'),
                child: Row(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pick(
                          ref,
                          'Premium: unlimited downloads, more AI. Core devotion stays free.',
                          'प्रीमियम: असीमित डाउनलोड, अधिक AI। मूल भक्ति हमेशा निःशुल्क।',
                        ),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
                      Text(
                        tr(ref, key),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.1),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (30 * i).ms).scale(begin: const Offset(0.92, 0.92)),
            ],
          ),
        ],
      ),
    );
  }
}
