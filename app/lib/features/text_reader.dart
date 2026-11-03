import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/audio.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/telugu.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class TextListScreen extends ConsumerWidget {
  const TextListScreen({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(textsProvider(kind));
    final deities = ref.watch(deitiesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, kind))),
      body: texts.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(textsProvider(kind))),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.menu_book_rounded, title: 'Coming soon')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final t = list[i];
                  final deity = deityById(deities, t.deityId);
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: SizedBox(
                        width: 52,
                        height: 52,
                        child: NetImage(deity?.imageUrl ?? '', radius: 26, color: Palette.hex(deity?.color ?? '')),
                      ),
                      title: Text(
                        t.titleHi.isNotEmpty ? t.titleHi : t.title,
                        style: const TextStyle(fontFamily: scriptureFont, fontSize: 18),
                      ),
                      subtitle: Text(t.title),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/text/${t.slug}'),
                    ),
                  ).animate().fadeIn(delay: (30 * i.clamp(0, 10)).ms).slideX(begin: 0.05);
                },
              ),
      ),
    );
  }
}

class TextReaderScreen extends ConsumerStatefulWidget {
  const TextReaderScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<TextReaderScreen> createState() => _TextReaderScreenState();
}

class _TextReaderScreenState extends ConsumerState<TextReaderScreen> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // keep the screen on while reciting
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(textProvider(widget.slug));
    final prefs = ref.watch(prefsProvider);
    return Scaffold(
      body: item.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(textProvider(widget.slug))),
        data: (t) => CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(t.titleHi.isNotEmpty ? t.titleHi : t.title),
              actions: [
                FavoriteButton(
                  item: FavoriteItem(type: 'text', id: t.slug, title: t.title, subtitle: t.titleHi),
                ),
                IconButton(
                  onPressed: () =>
                      SharePlus.instance.share(ShareParams(text: '${t.titleHi}\n\n${t.body}\n\n— Devalay')),
                  icon: const Icon(Icons.share_rounded),
                ),
                IconButton(onPressed: () => _settings(context), icon: const Icon(Icons.text_fields_rounded)),
              ],
            ),
            SliverToBoxAdapter(child: _AudioForText(slug: t.slug)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList.list(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Palette.marigold.withValues(alpha: context.isDark ? 0.08 : 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Palette.marigold.withValues(alpha: 0.3)),
                    ),
                    child: SelectableText(
                      uiLang(ref) == 'te' ? toTeluguScript(t.body) : t.body,
                      textAlign: TextAlign.center,
                      style: scriptureStyle(context, size: 20 * prefs.textScale),
                    ),
                  ),
                  if (prefs.showTransliteration && t.transliteration.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Transliteration', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SelectableText(
                      t.transliteration,
                      style: TextStyle(fontSize: 16 * prefs.textScale, height: 1.7, fontStyle: FontStyle.italic),
                    ),
                  ],
                  if (prefs.showMeaning && t.meaning.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(l3(ref, 'Meaning', 'भावार्थ', 'భావం'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(t.meaning, style: TextStyle(fontSize: 16 * prefs.textScale, height: 1.6)),
                  ],
                  if (t.benefits.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Text('🌼', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(t.benefits)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Attribution(t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _settings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final prefs = ref.watch(prefsProvider);
          final n = ref.read(prefsProvider.notifier);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_decrease_rounded),
                    Expanded(
                      child: Slider(
                        value: prefs.textScale,
                        min: 0.8,
                        max: 1.8,
                        divisions: 10,
                        onChanged: (v) => n.set('text_scale', v),
                      ),
                    ),
                    const Icon(Icons.text_increase_rounded),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Show transliteration'),
                  value: prefs.showTransliteration,
                  onChanged: (v) => n.set('show_translit', v),
                ),
                SwitchListTile(
                  title: const Text('Show meaning'),
                  value: prefs.showMeaning,
                  onChanged: (v) => n.set('show_meaning', v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// If a recording exists for this text, offer to play it.
class _AudioForText extends ConsumerWidget {
  const _AudioForText({required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider((kind: null, deity: null))).value ?? const <Track>[];
    final matches = tracks.where((t) => t.textSlug == slug).toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: FilledButton.tonalIcon(
        onPressed: () {
          ref.read(audioProvider).playQueue(matches);
          context.push('/player');
        },
        icon: const Icon(Icons.play_circle_fill_rounded),
        label: Text(l3(ref, 'Listen along', 'साथ में सुनें', 'వింటూ చదవండి')),
      ),
    );
  }
}
