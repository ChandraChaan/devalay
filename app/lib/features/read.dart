import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ReadScreen extends ConsumerWidget {
  const ReadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = [
      ('📿', 'chalisa', Palette.sunrise),
      ('🪔', 'aarti', Palette.dusk),
      ('🕉️', 'mantra', Palette.sky),
      ('🙏', 'stotra', Palette.tulsi),
      ('🌸', 'stuti', const [Color(0xFF6A1B9A), Color(0xFFAD1457)]),
    ];
    final books = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'read')),
        actions: [IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          GradientCard(
            colors: const [Color(0xFF3E2723), Palette.maroon, Color(0xFFBF360C)],
            onTap: () => context.push('/gita'),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'श्रीमद्भगवद्गीता',
                        style: TextStyle(fontFamily: scriptureFont, color: Palette.gold, fontSize: 26),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(ref, 'gita'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        '18 chapters · 701 verses · Sanskrit, transliteration, English',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Text('🪈', style: TextStyle(fontSize: 48)),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 12),
          GradientCard(
            colors: const [Color(0xFF0D47A1), Color(0xFF4A148C)],
            onTap: () => context.push('/ask'),
            padding: 16,
            child: Row(
              children: [
                const Text('🙋', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(ref, 'ask_gita'),
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Ask a life question, get answers grounded in Gita verses',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ).animate().fadeIn(delay: 80.ms),
          SectionHeader(pick(ref, 'Prayers & Paath', 'प्रार्थना और पाठ')),
          GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: [
              for (final (i, (emoji, kind, colors)) in sections.indexed)
                GradientCard(
                  colors: colors,
                  padding: 14,
                  onTap: () => context.push('/texts/$kind'),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr(ref, kind),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (60 * i).ms).scale(begin: const Offset(0.94, 0.94)),
            ],
          ),
          SectionHeader(tr(ref, 'books')),
          books.when(
            loading: () => const SkeletonBox(height: 200),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(booksProvider)),
            data: (list) => Column(
              children: [
                for (final b in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 48,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: Palette.sunrise),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('📜', style: TextStyle(fontSize: 24)),
                        ),
                        title: Text(pick(ref, b.title, b.titleHi), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${b.author}\n${b.chapterCount} chapters'),
                        isThreeLine: true,
                        onTap: () => context.push('/books/${b.slug}'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
