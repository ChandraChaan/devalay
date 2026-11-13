import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../core/favorites.dart';
import '../core/gita_voice.dart';
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final parts = (last ?? '1.1').split('.');
                          context.push('/gita/${parts[0]}?verse=${parts[1]}&play=1');
                        },
                        icon: const Icon(Icons.headphones_rounded),
                        label: Text(l3(ref, 'Listen', 'सुनें', 'వినండి')),
                      ),
                    ),
                    if (last != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            final parts = last.split('.');
                            context.push('/gita/${parts[0]}?verse=${parts[1]}');
                          },
                          icon: const Icon(Icons.bookmark_rounded),
                          label: Text(
                            l3(ref, 'Continue $last', 'जारी रखें $last', 'కొనసాగించండి $last'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
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
                            IconButton.filledTonal(
                              tooltip: l3(ref, 'Listen to chapter', 'अध्याय सुनें', 'అధ్యాయం వినండి'),
                              onPressed: () => context.push('/gita/${c.number}?verse=1&play=1'),
                              icon: const Icon(Icons.play_arrow_rounded),
                            ),
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
  const GitaChapterScreen({super.key, required this.chapter, this.initialVerse, this.autoPlay = false});
  final int chapter;
  final int? initialVerse;

  /// Start reading aloud as soon as the chapter loads.
  final bool autoPlay;
  @override
  ConsumerState<GitaChapterScreen> createState() => _GitaChapterScreenState();
}

class _GitaChapterScreenState extends ConsumerState<GitaChapterScreen> {
  late final PageController _page = PageController(initialPage: widget.initialVerse ?? 0);
  late final GitaVoice _voice;
  int _current = 0;
  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(gitaVoiceProvider.notifier);
    _current = widget.initialVerse ?? 0;
  }

  @override
  void dispose() {
    _voice.stop(owner: this);
    _page.dispose();
    super.dispose();
  }

  void _play(GitaChapter c) {
    final start = _current == 0 ? 0 : _current - 1;
    if (_current == 0) _page.animateToPage(1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    _voice.play(
      c,
      start,
      owner: this,
      announce: true,
      onVerse: (i) {
        if (!mounted || !_page.hasClients) return;
        if (_page.page?.round() != i + 1) {
          _page.animateToPage(i + 1, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
        }
      },
      onDone: () {
        if (!mounted) return;
        if (widget.chapter < 18) {
          context.pushReplacement('/gita/${widget.chapter + 1}?verse=1&play=1');
        } else {
          toast(context, l3(ref, 'Hari Om Tat Sat 🙏', 'हरि ॐ तत् सत् 🙏', 'హరి ఓం తత్ సత్ 🙏'));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gitaChapterProvider(widget.chapter));
    final prefs = ref.watch(prefsProvider);
    final voice = ref.watch(gitaVoiceProvider);
    final playingHere = voice.playing && voice.chapter == widget.chapter;
    ref.listen(gitaVoiceProvider.select((v) => v.noSanskritVoice), (_, missing) {
      if (missing) {
        toast(
          context,
          l3(
            ref,
            'No Hindi voice on this phone, reading the translation only. Add one in Settings › Text-to-speech.',
            'इस फ़ोन में हिंदी आवाज़ नहीं है, केवल अनुवाद पढ़ा जाएगा।',
            'ఈ ఫోన్‌లో హిందీ వాయిస్ లేదు, అనువాదం మాత్రమే చదువుతాం.',
          ),
        );
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text('${l3(ref, 'Chapter', 'अध्याय', 'అధ్యాయం')} ${widget.chapter}'),
        actions: [
          IconButton(
            tooltip: t3(appLang, 'Transliteration', 'लिप्यंतरण', 'లిప్యంతరీకరణ'),
            onPressed: () => ref.read(prefsProvider.notifier).set('show_translit', !prefs.showTransliteration),
            icon: Icon(
              prefs.showTransliteration ? Icons.translate_rounded : Icons.translate_outlined,
              color: prefs.showTransliteration ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          IconButton(
            tooltip: l3(ref, 'Text size', 'अक्षर आकार', 'అక్షర పరిమాణం'),
            onPressed: () {
              const steps = [0.9, 1.0, 1.15, 1.3];
              final i = steps.indexWhere((s) => (s - prefs.textScale).abs() < 0.01);
              ref.read(prefsProvider.notifier).set('text_scale', steps[(i + 1) % steps.length]);
            },
            icon: const Icon(Icons.format_size_rounded),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(gitaChapterProvider(widget.chapter))),
        data: (c) {
          if (widget.autoPlay && !_autoStarted) {
            _autoStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _play(c);
            });
          }
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  itemCount: c.verses.length + 1,
                  onPageChanged: (i) {
                    setState(() => _current = i);
                    if (i > 0) Boxes.stats.put('gita_last', '${c.number}.${c.verses[i - 1].verse}');
                    // The reader swiped to another verse: carry on reading from there.
                    final v = ref.read(gitaVoiceProvider);
                    if (v.playing && v.chapter == c.number && i > 0 && v.index != i - 1) _play(c);
                  },
                  itemBuilder: (_, i) => i == 0 ? _ChapterIntro(chapter: c) : _VersePage(verse: c.verses[i - 1]),
                ),
              ),
              _PlayerBar(
                chapter: c,
                current: _current,
                playing: playingHere,
                onSeek: (v) => _page.jumpToPage(v),
                onPrev: _current == 0
                    ? null
                    : () => _page.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                onNext: _current >= c.verses.length
                    ? (widget.chapter < 18
                          ? () => context.pushReplacement(
                              '/gita/${widget.chapter + 1}${playingHere ? '?verse=1&play=1' : ''}',
                            )
                          : null)
                    : () => _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                onToggle: () => playingHere ? _voice.stop() : _play(c),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({
    required this.chapter,
    required this.current,
    required this.playing,
    required this.onSeek,
    required this.onPrev,
    required this.onNext,
    required this.onToggle,
  });
  final GitaChapter chapter;
  final int current;
  final bool playing;
  final ValueChanged<int> onSeek;
  final VoidCallback? onPrev, onNext;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(gitaVoiceProvider);
    final scheme = Theme.of(context).colorScheme;
    final total = chapter.verses.length;
    final modeLabel = switch (voice.mode) {
      GitaReadMode.both => l3(ref, 'Sanskrit + meaning', 'संस्कृत + अर्थ', 'సంస్కృతం + అర్థం'),
      GitaReadMode.sanskrit => l3(ref, 'Sanskrit only', 'केवल संस्कृत', 'సంస్కృతం మాత్రమే'),
      GitaReadMode.translation => l3(ref, 'Meaning only', 'केवल अर्थ', 'అర్థం మాత్రమే'),
    };
    return Material(
      color: scheme.surfaceContainer,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 12),
                  Text(
                    current == 0
                        ? l3(ref, 'Intro', 'परिचय', 'పరిచయం')
                        : '${chapter.number}.${chapter.verses[current - 1].verse}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(
                        context,
                      ).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
                      child: Slider(
                        value: current.toDouble(),
                        max: total.toDouble(),
                        divisions: total,
                        label: current == 0 ? 'Intro' : '${chapter.number}.${chapter.verses[current - 1].verse}',
                        onChanged: (v) => onSeek(v.round()),
                      ),
                    ),
                  ),
                  Text('$total', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 12),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => ref.read(gitaVoiceProvider.notifier).cycleRate(),
                    style: TextButton.styleFrom(minimumSize: const Size(56, 40)),
                    child: Text(
                      '${voice.rate.toString().replaceAll(RegExp(r'\.0$'), '')}×',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  IconButton(iconSize: 30, onPressed: onPrev, icon: const Icon(Icons.skip_previous_rounded)),
                  const SizedBox(width: 8),
                  _PlayButton(playing: playing, onTap: onToggle),
                  const SizedBox(width: 8),
                  IconButton(iconSize: 30, onPressed: onNext, icon: const Icon(Icons.skip_next_rounded)),
                  const Spacer(),
                  PopupMenuButton<GitaReadMode>(
                    tooltip: modeLabel,
                    initialValue: voice.mode,
                    onSelected: (m) => ref.read(gitaVoiceProvider.notifier).setMode(m),
                    icon: const Icon(Icons.record_voice_over_rounded),
                    itemBuilder: (_) => [
                      for (final m in GitaReadMode.values)
                        CheckedPopupMenuItem(
                          value: m,
                          checked: voice.mode == m,
                          child: Text(switch (m) {
                            GitaReadMode.both => l3(ref, 'Sanskrit + meaning', 'संस्कृत + अर्थ', 'సంస్కృతం + అర్థం'),
                            GitaReadMode.sanskrit => l3(ref, 'Sanskrit only', 'केवल संस्कृत', 'సంస్కృతం మాత్రమే'),
                            GitaReadMode.translation => l3(ref, 'Meaning only', 'केवल अर्थ', 'అర్థం మాత్రమే'),
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: Palette.sunrise),
            boxShadow: [
              BoxShadow(
                color: Palette.saffron.withValues(alpha: playing ? 0.55 : 0.3),
                blurRadius: playing ? 22 : 12,
                spreadRadius: playing ? 2 : 0,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
              color: Colors.white,
              size: 36,
            ),
          ),
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
          child: Text(
            t3(appLang, 'Swipe to begin →', 'शुरू करने के लिए स्वाइप करें →', 'మొదలుపెట్టడానికి స్వైప్ చేయండి →'),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
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
    final voice = ref.watch(gitaVoiceProvider);
    final sayingSanskrit = voice.isSpeaking(verse, VersePart.sanskrit);
    final sayingMeaning = voice.isSpeaking(verse, VersePart.translation);
    final scheme = Theme.of(context).colorScheme;
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
                '${l3(ref, 'Verse', 'श्लोक', 'శ్లోకం')} ${verse.ref}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            FavoriteButton(
              item: FavoriteItem(
                type: 'verse',
                id: verse.ref,
                title: t3(appLang, 'Bhagavad Gita ${verse.ref}', 'भगवद गीता ${verse.ref}', 'భగవద్గీత ${verse.ref}'),
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sayingSanskrit ? Palette.marigold : Colors.transparent, width: 2),
            gradient: LinearGradient(
              colors: [
                Palette.marigold.withValues(alpha: sayingSanskrit ? 0.28 : 0.14),
                Palette.saffron.withValues(alpha: sayingSanskrit ? 0.12 : 0.06),
              ],
            ),
          ),
          child: Text(
            scriptFor(uiLang(ref), verse.sanskrit),
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
        const SizedBox(height: 14),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: sayingMeaning ? scheme.primary.withValues(alpha: 0.08) : Colors.transparent,
            border: Border(left: BorderSide(color: sayingMeaning ? scheme.primary : Colors.transparent, width: 3)),
          ),
          child: Text(verse.translation, style: TextStyle(fontSize: 18 * prefs.textScale, height: 1.6)),
        ),
        const SizedBox(height: 8),
        Text('— ${verse.translator}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
