import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../widgets/common.dart';

class BooksScreen extends ConsumerWidget {
  const BooksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'books'))),
      body: books.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(booksProvider)),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final b in list)
              Card(
                child: ListTile(
                  title: Text(pick(ref, b.title, b.titleHi)),
                  subtitle: Text(b.author),
                  onTap: () => context.push('/books/${b.slug}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BookScreen extends ConsumerStatefulWidget {
  const BookScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(bookProvider(widget.slug));
    final last = Boxes.stats.get('book_last_${widget.slug}') as int?;
    return Scaffold(
      body: book.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(bookProvider(widget.slug))),
        data: (b) {
          final chapters = b.chapters.where((c) => c.title.toLowerCase().contains(_filter.toLowerCase())).toList();
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(pick(ref, b.title, b.titleHi)),
                actions: [
                  FavoriteButton(
                    item: FavoriteItem(type: 'book', id: b.slug, title: b.title, subtitle: b.author),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.list(
                  children: [
                    Text(b.description, style: const TextStyle(fontSize: 16, height: 1.5)),
                    Attribution(b),
                    const SizedBox(height: 8),
                    if (last != null)
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/books/${b.slug}/$last'),
                        icon: const Icon(Icons.bookmark_rounded),
                        label: Text(
                          l3(
                            ref,
                            'Continue from chapter $last',
                            'अध्याय $last से जारी रखें',
                            '$last వ అధ్యాయం నుంచి కొనసాగించండి',
                          ),
                        ),
                      ),
                    if (b.chapters.length > 20)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: t3(appLang, 'Find a chapter', 'अध्याय खोजें', 'అధ్యాయం వెతకండి'),
                          ),
                          onChanged: (v) => setState(() => _filter = v),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              SliverList.builder(
                itemCount: chapters.length,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(child: Text('${chapters[i].number}', style: const TextStyle(fontSize: 12))),
                  title: Text(chapters[i].title),
                  onTap: () => context.push('/books/${b.slug}/${chapters[i].number}'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

class BookChapterScreen extends ConsumerStatefulWidget {
  const BookChapterScreen({super.key, required this.slug, required this.number});
  final String slug;
  final int number;
  @override
  ConsumerState<BookChapterScreen> createState() => _BookChapterScreenState();
}

class _BookChapterScreenState extends ConsumerState<BookChapterScreen> {
  @override
  void initState() {
    super.initState();
    Boxes.stats.put('book_last_${widget.slug}', widget.number);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = (slug: widget.slug, number: widget.number);
    final chapter = ref.watch(bookChapterProvider(q));
    final scale = ref.watch(prefsProvider.select((p) => p.textScale));
    return Scaffold(
      appBar: AppBar(title: Text('${widget.number}')),
      body: chapter.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(bookChapterProvider(q))),
        data: (c) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '${c['title']}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SelectableText('${c['body']}', style: TextStyle(fontSize: 17 * scale, height: 1.65)),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.number > 1)
                  OutlinedButton.icon(
                    onPressed: () => context.pushReplacement('/books/${widget.slug}/${widget.number - 1}'),
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: Text(t3(appLang, 'Previous', 'पिछला', 'మునుపటి')),
                  ),
                const Spacer(),
                if (c['has_next'] == true)
                  FilledButton.icon(
                    onPressed: () => context.pushReplacement('/books/${widget.slug}/${widget.number + 1}'),
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: Text(t3(appLang, 'Next', 'अगला', 'తదుపరి')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
