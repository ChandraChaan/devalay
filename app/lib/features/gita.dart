import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';

class GitaScreen extends ConsumerWidget {
  const GitaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(gitaChaptersProvider);
    final last = Boxes.stats.get('gita_last') as String?;
    return Scaffold(
      body: chapters.when(
        loading: () => const LoadingList(height: 90),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(gitaChaptersProvider)),
        data: (list) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              foregroundColor: Colors.white,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  tr(ref, 'gita'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3E2723), Palette.maroon, Color(0xFFBF360C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(right: -40, child: Mandala(size: 260, color: Palette.gold, opacity: 0.25)),
                      Text(
                        '॥ श्रीमद्भगवद्गीता ॥',
                        style: TextStyle(fontFamily: scriptureFont, color: Palette.gold, fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (last != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      final parts = last.split('.');
                      context.push('/gita/${parts[0]}?verse=${parts[1]}');
                    },
                    icon: const Icon(Icons.bookmark_rounded),
                    label: Text(pick(ref, 'Continue reading $last', 'पढ़ना जारी रखें $last')),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push('/gita/${c.number}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: Palette.sunrise),
                              ),
                              child: Text(
                                '${c.number}',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.nameSanskrit, style: const TextStyle(fontFamily: scriptureFont, fontSize: 18)),
                                  Text(c.nameEn, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('${c.verseCount} verses', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: (25 * i).ms).slideY(begin: 0.06);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GitaChapterScreen extends ConsumerStatefulWidget {
  const GitaChapterScreen({super.key, required this.chapter, this.initialVerse});
  final int chapter;
  final int? initialVerse;
  @override
  ConsumerState<GitaChapterScreen> createState() => _GitaChapterScreenState();
}

class _GitaChapterScreenState extends ConsumerState<GitaChapterScreen> {
  late final PageController _page = PageController(initialPage: widget.initialVerse ?? 0);
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialVerse ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gitaChapterProvider(widget.chapter));
    final prefs = ref.watch(prefsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${pick(ref, 'Chapter', 'अध्याय')} ${widget.chapter}'),
        actions: [
          IconButton(
            tooltip: 'Transliteration',
            onPressed: () => ref.read(prefsProvider.notifier).set('show_translit', !prefs.showTransliteration),
            icon: Icon(
              prefs.showTransliteration ? Icons.translate_rounded : Icons.translate_outlined,
              color: prefs.showTransliteration ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(gitaChapterProvider(widget.chapter))),
        data: (c) => Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: c.verses.length + 1,
                onPageChanged: (i) {
                  setState(() => _current = i);
                  if (i > 0) Boxes.stats.put('gita_last', '${c.number}.${c.verses[i - 1].verse}');
                },
                itemBuilder: (_, i) => i == 0 ? _ChapterIntro(chapter: c) : _VersePage(verse: c.verses[i - 1]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _current == 0
                        ? null
                        : () => _page.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Slider(
                      value: _current.toDouble(),
                      max: c.verses.length.toDouble(),
                      divisions: c.verses.length,
                      label: _current == 0 ? 'Intro' : '${c.number}.${c.verses[_current - 1].verse}',
                      onChanged: (v) => _page.jumpToPage(v.round()),
                    ),
                  ),
                  IconButton(
                    onPressed: _current >= c.verses.length
                        ? (widget.chapter < 18 ? () => context.pushReplacement('/gita/${widget.chapter + 1}') : null)
                        : () => _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    icon: const Icon(Icons.chevron_right_rounded),
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

class _ChapterIntro extends StatelessWidget {
  const _ChapterIntro({required this.chapter});
  final GitaChapter chapter;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(child: Text(chapter.nameSanskrit, style: scriptureStyle(context, size: 32))),
        Center(
          child: Text(chapter.nameTranslit, style: const TextStyle(fontStyle: FontStyle.italic)),
        ),
        const SizedBox(height: 8),
        Center(child: Text(chapter.nameEn, style: Theme.of(context).textTheme.headlineSmall)),
        const SizedBox(height: 24),
        Text(chapter.summary, style: const TextStyle(fontSize: 17, height: 1.6)),
        const SizedBox(height: 24),
        Center(
          child: Text('Swipe to begin →', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
      ],
    ).animate().fadeIn();
  }
}

class _VersePage extends ConsumerWidget {
  const _VersePage({required this.verse});
  final Verse verse;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Palette.marigold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${pick(ref, 'Verse', 'श्लोक')} ${verse.ref}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            FavoriteButton(
              item: FavoriteItem(
                type: 'verse',
                id: verse.ref,
                title: 'Bhagavad Gita ${verse.ref}',
                subtitle: verse.translation,
              ),
            ),
            IconButton(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      '${verse.sanskrit}\n\n${verse.translation}\n\n— Bhagavad Gita ${verse.ref} (tr. ${verse.translator})',
                ),
              ),
              icon: const Icon(Icons.share_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Palette.marigold.withValues(alpha: 0.14), Palette.saffron.withValues(alpha: 0.06)],
            ),
          ),
          child: Text(
            verse.sanskrit,
            textAlign: TextAlign.center,
            style: scriptureStyle(context, size: 21 * prefs.textScale),
          ),
        ),
        if (prefs.showTransliteration) ...[
          const SizedBox(height: 14),
          Text(
            verse.transliteration,
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15 * prefs.textScale, height: 1.6),
          ),
        ],
        const SizedBox(height: 20),
        Text(verse.translation, style: TextStyle(fontSize: 18 * prefs.textScale, height: 1.6)),
        const SizedBox(height: 8),
        Text('— ${verse.translator}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
