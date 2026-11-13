import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/audio.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/names.dart';
import '../core/providers.dart';
import '../widgets/common.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Timer? _debounce;
  Map? _results;
  bool _loading = false;
  Object? _error;
  String _q = '';

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    _q = q.trim();
    if (_q.length < 2) {
      setState(() => _results = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiProvider).get('/search', query: {'q': _q, 'limit': 15}) as Map;
      if (mounted && q.trim() == _q) {
        setState(() {
          _results = r;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _results;
    final tracks = r == null ? <Track>[] : (r['tracks'] as List).map((t) => Track(t as Map)).toList();
    final texts = r == null ? <TextSummary>[] : (r['texts'] as List).map((t) => TextSummary(t as Map)).toList();
    final books = r == null ? <Book>[] : (r['books'] as List).map((b) => Book(b as Map)).toList();
    final walls = r == null ? <Wallpaper>[] : (r['wallpapers'] as List).map((w) => Wallpaper(w as Map)).toList();
    final verses = r == null ? <Verse>[] : (r['verses'] as List).map((v) => Verse(v as Map)).toList();
    final lang = uiLang(ref);
    // Festivals and vratas come from the calendar on the phone, so "ugadi" or "ఏకాదశి" finds the next dates.
    final today = DateUtils.dateOnly(DateTime.now());
    final q = _q.toLowerCase();
    final festivals = q.length < 2
        ? const <Festival>[]
        : [
            for (final y in [today.year, today.year + 1])
              ...?ref
                  .watch(festivalsProvider(y))
                  .value
                  ?.where(
                    (f) =>
                        !f.date.isBefore(today) &&
                        (f.label(lang).toLowerCase().contains(q) ||
                            f.name.toLowerCase().contains(q) ||
                            f.nameHi.contains(_q)),
                  ),
          ].take(8).toList();
    final empty =
        r != null &&
        festivals.isEmpty &&
        tracks.isEmpty &&
        texts.isEmpty &&
        books.isEmpty &&
        walls.isEmpty &&
        verses.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText:
                '${tr(ref, 'search')}: ${t3(uiLang(ref), 'Hanuman, Diwali, karma…', 'हनुमान, दिवाली, कर्म…', 'హనుమాన్, ఉగాది, కర్మ…')}',
            filled: false,
            border: InputBorder.none,
          ),
        ),
      ),
      body: _loading && r == null
          ? const LoadingList()
          : _error != null
          ? ErrorRetry(error: _error!, onRetry: () => _search(_q))
          : r == null
          ? EmptyState(
              icon: Icons.search_rounded,
              title: t3(
                lang,
                'Search bhajans, aartis, mantras, scriptures, Gita verses and festivals',
                'भजन, आरती, मंत्र, ग्रंथ, गीता श्लोक और त्योहार खोजें',
                'భజనలు, ఆరతులు, మంత్రాలు, గ్రంథాలు, గీతా శ్లోకాలు, పండుగలు వెతకండి',
              ),
            )
          : empty
          ? EmptyState(icon: Icons.search_off_rounded, title: t3(lang, 'No results', 'कुछ नहीं मिला', 'ఏమీ దొరకలేదు'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (festivals.isNotEmpty) SectionHeader(t3(lang, 'Festivals', 'त्योहार', 'పండుగలు')),
                for (final f in festivals)
                  ListTile(
                    leading: Text(f.major ? '🪔' : '🙏', style: const TextStyle(fontSize: 26)),
                    title: Text(f.label(lang)),
                    subtitle: Text(fmtDate(lang, 'EEE, d MMM y', f.date)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/calendar/day/${DateFormat('yyyy-MM-dd').format(f.date)}'),
                  ),
                if (tracks.isNotEmpty) SectionHeader(tr(ref, 'listen')),
                for (final (i, t) in tracks.indexed)
                  ListTile(
                    leading: SizedBox(width: 48, height: 48, child: NetImage(t.artworkUrl, radius: 10)),
                    title: Text(t.label(uiLang(ref))),
                    subtitle: Text(tr(ref, t.kind)),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () => ref.read(audioProvider).playQueue(tracks, index: i),
                  ),
                if (texts.isNotEmpty) SectionHeader(tr(ref, 'read')),
                for (final t in texts)
                  ListTile(
                    leading: const Text('📜', style: TextStyle(fontSize: 26)),
                    title: Text(t.label(uiLang(ref))),
                    subtitle: Text(tr(ref, t.kind)),
                    onTap: () => context.push('/text/${t.slug}'),
                  ),
                if (verses.isNotEmpty) SectionHeader(tr(ref, 'gita')),
                for (final v in verses)
                  ListTile(
                    leading: CircleAvatar(child: Text(v.ref, style: const TextStyle(fontSize: 11))),
                    title: Text(v.translation, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => context.push('/gita/${v.chapter}?verse=${v.verse}'),
                  ),
                if (books.isNotEmpty) SectionHeader(tr(ref, 'books')),
                for (final b in books)
                  ListTile(
                    title: Text(b.title),
                    subtitle: Text(b.author),
                    onTap: () => context.push('/books/${b.slug}'),
                  ),
                if (walls.isNotEmpty) SectionHeader(tr(ref, 'wallpapers')),
                if (walls.isNotEmpty)
                  SizedBox(
                    height: 160,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final w in walls)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => context.push('/wallpaper', extra: w),
                              child: SizedBox(width: 100, child: NetImage(w.thumbUrl, radius: 12)),
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
