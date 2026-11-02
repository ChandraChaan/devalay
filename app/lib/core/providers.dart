import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'location.dart';
import 'models.dart';
import 'storage.dart';

/// Read-only data providers. Each caches through [Api.get] for offline use.

final homeProvider = FutureProvider<Map>((ref) async {
  final city = ref.watch(cityProvider);
  return await ref.read(apiProvider).get('/home', query: city.query) as Map;
});

final deitiesProvider = FutureProvider<List<Deity>>((ref) async {
  final data = await ref.read(apiProvider).get('/deities') as List;
  return data.map((d) => Deity(d as Map)).toList();
});

Deity? deityById(List<Deity> all, int? id) {
  for (final d in all) {
    if (d.id == id) return d;
  }
  return null;
}

typedef TrackQuery = ({String? kind, String? deity});

final tracksProvider = FutureProvider.family<List<Track>, TrackQuery>((ref, q) async {
  final data =
      await ref.read(apiProvider).get('/tracks', query: {'page_size': 100, 'kind': ?q.kind, 'deity': ?q.deity}) as Map;
  return (data['items'] as List).map((t) => Track(t as Map)).toList();
});

final textsProvider = FutureProvider.family<List<TextSummary>, String?>((ref, kind) async {
  final data = await ref.read(apiProvider).get('/texts', query: {'page_size': 100, 'kind': ?kind}) as Map;
  return (data['items'] as List).map((t) => TextSummary(t as Map)).toList();
});

final textProvider = FutureProvider.family<TextItem, String>((ref, slug) async {
  return TextItem(await ref.read(apiProvider).get('/texts/$slug') as Map);
});

final gitaChaptersProvider = FutureProvider<List<GitaChapter>>((ref) async {
  final data = await ref.read(apiProvider).get('/gita/chapters') as List;
  return data.map((c) => GitaChapter(c as Map)).toList();
});

final gitaChapterProvider = FutureProvider.family<GitaChapter, int>((ref, n) async {
  return GitaChapter(await ref.read(apiProvider).get('/gita/chapters/$n') as Map);
});

final booksProvider = FutureProvider<List<Book>>((ref) async {
  final data = await ref.read(apiProvider).get('/books') as List;
  return data.map((b) => Book(b as Map)).toList();
});

final bookProvider = FutureProvider.family<Book, String>((ref, slug) async {
  return Book(await ref.read(apiProvider).get('/books/$slug') as Map);
});

final bookChapterProvider = FutureProvider.family<Map, ({String slug, int number})>((ref, q) async {
  return await ref.read(apiProvider).get('/books/${q.slug}/chapters/${q.number}') as Map;
});

final wallpapersProvider = FutureProvider.family<List<Wallpaper>, String?>((ref, deity) async {
  final data = await ref.read(apiProvider).get('/wallpapers', query: {'page_size': 100, 'deity': ?deity}) as Map;
  return (data['items'] as List).map((w) => Wallpaper(w as Map)).toList();
});

final videosProvider = FutureProvider<List<Video>>((ref) async {
  final data = await ref.read(apiProvider).get('/videos') as Map;
  return (data['items'] as List).map((v) => Video(v as Map)).toList();
});

final panchangProvider = FutureProvider.family<Map, DateTime>((ref, day) async {
  final city = ref.watch(cityProvider);
  final d = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return await ref.read(apiProvider).get('/panchang', query: {...city.query, 'day': d}) as Map;
});

final monthProvider = FutureProvider.family<List<Map>, ({int year, int month})>((ref, q) async {
  final city = ref.watch(cityProvider);
  final data =
      await ref.read(apiProvider).get('/panchang/month', query: {...city.query, 'year': q.year, 'month': q.month})
          as Map;
  return (data['days'] as List).cast<Map>();
});

final festivalsProvider = FutureProvider.family<List<Festival>, int>((ref, year) async {
  final city = ref.watch(cityProvider);
  final data =
      await ref.read(apiProvider).get('/festivals', query: {...city.query, 'year': year, 'include_recurring': true})
          as List;
  return data.map((f) => Festival(f as Map)).toList();
});

final rashifalProvider = FutureProvider<List<Map>>((ref) async {
  final lang = ref.watch(prefsProvider.select((p) => p.language));
  final data = await ref.read(apiProvider).get('/rashifal', query: {'lang': lang}) as Map;
  return (data['readings'] as List).cast<Map>();
});

final configProvider = FutureProvider<Map>((ref) async => await ref.read(apiProvider).get('/config') as Map);
