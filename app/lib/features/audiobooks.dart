import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/audio.dart';
import '../core/audiobooks.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';

const _groups = <String, (String, String, String, String)>{
  'gita': ('🪷', 'Bhagavad Gita', 'भगवद्गीता', 'భగవద్గీత'),
  'ramayana': ('🏹', 'Ramayana', 'रामायण', 'రామాయణం'),
  'mahabharata': ('⚔️', 'Mahabharata', 'महाभारत', 'మహాభారతం'),
  'upanishads': ('🕉️', 'Upanishads', 'उपनिषद', 'ఉపనిషత్తులు'),
  'more': ('📚', 'More to listen to', 'और सुनें', 'ఇంకా వినండి'),
};

/// Audiobooks read by people (LibriVox volunteers, public domain), grouped by scripture.
class AudiobooksScreen extends ConsumerWidget {
  const AudiobooksScreen({super.key, this.appBook});

  /// Only the audiobooks of this Read book (e.g. the six Ramayana books).
  final String? appBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final lib = ref.watch(audioLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Audiobooks', 'ऑडियोबुक', 'ఆడియో పుస్తకాలు'))),
      body: lib.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(audioLibraryProvider)),
        data: (l) {
          final books = appBook == null ? l.books : l.forBook(appBook!);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24).withSystemInsets(context),
            children: [
              if (appBook == null)
                GradientCard(
                  colors: const [Color(0xFF3E2723), Color(0xFF6D4C41), Color(0xFFBF8F00)],
                  child: Text(
                    t3(
                      lang,
                      'The Gita, Ramayana, Mahabharata and Upanishads read aloud by people, free. From LibriVox, whose volunteers give their recordings to the public domain.',
                      'गीता, रामायण, महाभारत और उपनिषद, लोगों की आवाज़ में, मुफ़्त। LibriVox से, जिसके स्वयंसेवक अपनी रिकॉर्डिंग सार्वजनिक डोमेन को देते हैं।',
                      'గీత, రామాయణం, మహాభారతం, ఉపనిషత్తులు మనుషుల గొంతుతో, ఉచితంగా. LibriVox స్వచ్ఛంద సేవకులు తమ రికార్డింగ్‌లను పబ్లిక్ డొమైన్‌కు ఇస్తారు.',
                    ),
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
              for (final g in _groups.entries)
                if (books.any((b) => b.group == g.key)) ...[
                  SectionHeader('${g.value.$1}  ${t3(lang, g.value.$2, g.value.$3, g.value.$4)}'),
                  for (final b in books.where((b) => b.group == g.key)) _BookTile(book: b),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});
  final Audiobook book;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.headphones_rounded)),
      title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${book.byline}\n${hoursMinutes(book.seconds)} · ${book.sections.length} parts${book.language == 'English' ? '' : ' · ${book.language}'}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AudiobookScreen(book: book))),
    ),
  );
}

class AudiobookScreen extends ConsumerWidget {
  const AudiobookScreen({super.key, required this.book});
  final Audiobook book;

  void _play(BuildContext context, WidgetRef ref, int index) {
    final tracks = [
      for (final (i, s) in book.sections.indexed)
        partTrack(
          s,
          id: audioTrackId(book.id, i),
          title: '${book.title}: ${s.title}',
          artist: s.reader.isEmpty ? 'LibriVox' : '${s.reader} (LibriVox)',
          license: 'Public domain',
          source: book.source,
        ),
    ];
    Usage.record('audiobook_play', item: '${book.id}:$index');
    ref.read(audioProvider).playQueue(tracks, index: index, from: 'audiobook');
    context.push('/player');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    return Scaffold(
      appBar: AppBar(title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24).withSystemInsets(context),
        children: [
          Text(book.byline, style: Theme.of(context).textTheme.titleSmall),
          Text('${hoursMinutes(book.seconds)} · ${book.sections.length} parts'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _play(context, ref, 0),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(t3(lang, 'Play from the start', 'शुरू से चलाएँ', 'మొదటి నుండి వినండి')),
          ),
          const SizedBox(height: 8),
          for (final (i, s) in book.sections.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 16, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              title: Text(s.title),
              subtitle: Text([hoursMinutes(s.seconds), if (s.reader.isNotEmpty) s.reader].join(' · ')),
              trailing: const Icon(Icons.play_circle_outline_rounded),
              onTap: () => _play(context, ref, i),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(book.source), mode: LaunchMode.externalApplication),
            child: Text(
              t3(
                lang,
                'LibriVox recording · public domain · source',
                'LibriVox रिकॉर्डिंग · सार्वजनिक डोमेन · स्रोत',
                'LibriVox రికార్డింగ్ · పబ్లిక్ డొమైన్ · మూలం',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Listen" on a Read book: opens its audiobook, or the list when it has several (Ramayana books 1-6).
class BookListenCard extends ConsumerWidget {
  const BookListenCard({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final books = ref.watch(audioLibraryProvider).value?.forBook(slug) ?? const <Audiobook>[];
    if (books.isEmpty) return const SizedBox.shrink();
    final total = books.fold<int>(0, (s, b) => s + b.seconds);
    return Card(
      color: Palette.marigold.withValues(alpha: 0.15),
      child: ListTile(
        leading: const Icon(Icons.headphones_rounded, color: Palette.saffron),
        title: Text(
          t3(lang, 'Listen to this book', 'यह पुस्तक सुनें', 'ఈ పుస్తకం వినండి'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${t3(lang, 'Read aloud by people', 'लोगों की आवाज़ में', 'మనుషుల గొంతుతో')} · ${hoursMinutes(total)}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => books.length == 1 ? AudiobookScreen(book: books.first) : AudiobooksScreen(appBook: slug),
          ),
        ),
      ),
    );
  }
}

/// Human voices for the Gita: the English reading of the whole Gita or one chapter (LibriVox, public
/// domain), and Sanskrit chanting where an openly licensed recording exists (chapters 1-3, CC BY-SA 4.0).
class GitaHumanVoices extends ConsumerWidget {
  const GitaHumanVoices({super.key, this.chapter});

  /// One chapter, or the whole Gita when null.
  final int? chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final lib = ref.watch(audioLibraryProvider).value;
    if (lib == null || lib.gitaEnglish.isEmpty) return const SizedBox.shrink();
    final english = chapter == null
        ? [for (var i = 0; i <= 18; i++) ?lib.gitaEnglish[i]]
        : [?lib.gitaEnglish[chapter!]];
    final sanskritChapters = chapter == null ? (lib.gitaSanskrit.keys.toList()..sort()) : [?chapter];
    final sanskrit = [for (final c in sanskritChapters) ...?lib.gitaSanskrit[c]];
    final englishSeconds = english.fold<int>(0, (s, p) => s + p.seconds);
    final sanskritSeconds = sanskrit.fold<int>(0, (s, p) => s + p.seconds);

    void play(List<AudioPart> parts, {required bool sanskritVoice}) {
      final tracks = [
        for (final (i, p) in parts.indexed)
          partTrack(
            p,
            id: audioTrackId(sanskritVoice ? 'gita-sa' : 'gita-en', (chapter ?? 0) * 200 + i),
            title: sanskritVoice ? p.title : 'Bhagavad Gita: ${p.title}',
            artist: sanskritVoice ? p.reader : '${lib.gitaEnglishReader} (LibriVox)',
            license: sanskritVoice ? 'CC BY-SA 4.0' : 'Public domain',
            source: sanskritVoice ? p.source : 'https://librivox.org/the-bhagavad-gita/',
            kind: 'gita',
          ),
      ];
      Usage.record('gita_human_voice', item: '${sanskritVoice ? 'sa' : 'en'}:${chapter ?? 'all'}');
      ref.read(audioProvider).playQueue(tracks, from: 'gita');
      context.push('/player');
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t3(lang, 'Human voices', 'मानव स्वर', 'మనుషుల గొంతుతో'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (english.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.record_voice_over_rounded)),
                title: Text(
                  chapter == null
                      ? t3(
                          lang,
                          'The whole Gita, read in English',
                          'पूरी गीता, अंग्रेज़ी में पाठ',
                          'పూర్తి గీత, ఇంగ్లీష్‌లో పఠనం',
                        )
                      : t3(lang, 'This chapter, read in English', 'यह अध्याय, अंग्रेज़ी में', 'ఈ అధ్యాయం, ఇంగ్లీష్‌లో'),
                ),
                subtitle: Text('${lib.gitaEnglishReader} · Edwin Arnold · ${hoursMinutes(englishSeconds)}'),
                trailing: const Icon(Icons.play_circle_fill_rounded, size: 34, color: Palette.saffron),
                onTap: () => play(english, sanskritVoice: false),
              ),
            if (sanskrit.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Text('ॐ', style: TextStyle(fontSize: 18))),
                title: Text(
                  chapter == null
                      ? t3(
                          lang,
                          'Sanskrit chanting, chapters ${sanskritChapters.join(', ')}',
                          'संस्कृत पाठ, अध्याय ${sanskritChapters.join(', ')}',
                          'సంస్కృత పఠనం, అధ్యాయాలు ${sanskritChapters.join(', ')}',
                        )
                      : t3(lang, 'Sanskrit chanting', 'संस्कृत पाठ', 'సంస్కృత పఠనం'),
                ),
                subtitle: Text(
                  '${{for (final p in sanskrit) p.reader}.join(', ')} · CC BY-SA 4.0 · ${hoursMinutes(sanskritSeconds)}',
                ),
                trailing: const Icon(Icons.play_circle_fill_rounded, size: 34, color: Palette.saffron),
                onTap: () => play(sanskrit, sanskritVoice: true),
              ),
          ],
        ),
      ),
    );
  }
}
