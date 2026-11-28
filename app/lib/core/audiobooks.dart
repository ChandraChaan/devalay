import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'json_asset.dart';
import 'models.dart';

/// Human voices for the Gita and the Read section (assets/data/audiobooks.json, built by
/// backend/scripts/build_audiobooks.py). LibriVox audiobooks are public domain and stream from archive.org;
/// the Sanskrit Gita chanting (chapters 1-3) is CC BY-SA 4.0 from Wikimedia Commons.

class AudioPart {
  AudioPart(Map m)
    : title = '${m['title'] ?? ''}',
      url = '${m['url']}',
      seconds = (m['seconds'] as num?)?.toInt() ?? 0,
      reader = '${m['reader'] ?? m['performer'] ?? ''}',
      verse = (m['verse'] as num?)?.toInt(),
      source = '${m['source'] ?? ''}';
  final String title, url, reader, source;
  final int seconds;
  final int? verse;
}

class Audiobook {
  Audiobook(Map m)
    : id = '${m['id']}',
      group = '${m['group'] ?? 'more'}',
      appBook = m['app_book'] as String?,
      title = '${m['title']}',
      author = '${m['author'] ?? ''}',
      translator = '${m['translator'] ?? ''}',
      readers = [for (final r in m['readers'] as List? ?? const []) '$r'],
      license = '${m['license'] ?? ''}',
      source = '${m['source'] ?? ''}',
      seconds = (m['seconds'] as num?)?.toInt() ?? 0,
      language = '${m['language'] ?? 'English'}',
      sections = [for (final s in m['sections'] as List? ?? const []) AudioPart(s as Map)];
  final String id, group, title, author, translator, license, source, language;
  final String? appBook;
  final List<String> readers;
  final int seconds;
  final List<AudioPart> sections;

  String get byline => [
    if (translator.isNotEmpty) 'tr. $translator' else if (author.isNotEmpty && author != 'Unknown') author,
    if (readers.length == 1) 'read by ${readers.first}' else if (readers.length > 1) '${readers.length} readers',
  ].join(' · ');
}

class AudioLibrary {
  AudioLibrary(Map json)
    : gitaEnglish = {
        for (final e in ((json['gita'] as Map?)?['english']?['chapters'] as Map? ?? const {}).entries)
          int.parse('${e.key}'): AudioPart(e.value as Map),
      },
      gitaEnglishReader = '${(json['gita'] as Map?)?['english']?['reader'] ?? ''}',
      gitaSanskrit = {
        for (final e in ((json['gita'] as Map?)?['sanskrit']?['chapters'] as Map? ?? const {}).entries)
          int.parse('${e.key}'): [for (final p in e.value as List) AudioPart(p as Map)],
      },
      books = [for (final b in json['books'] as List? ?? const []) Audiobook(b as Map)];

  /// Section 0 is the preface; 1-18 the chapters.
  final Map<int, AudioPart> gitaEnglish;
  final String gitaEnglishReader;

  /// Chapter → its recordings in order (one whole chapter, or verse by verse).
  final Map<int, List<AudioPart>> gitaSanskrit;
  final List<Audiobook> books;

  List<Audiobook> forBook(String slug) => books.where((b) => b.appBook == slug).toList();
}

final audioLibraryProvider = FutureProvider<AudioLibrary>(
  (ref) async => AudioLibrary(await loadJsonAsset('assets/data/audiobooks.json')),
);

/// A part as a player track, so it plays in the main player with its notification and queue.
Track partTrack(
  AudioPart p, {
  required int id,
  required String title,
  required String artist,
  required String license,
  String source = '',
  String artwork = '',
  String kind = 'audiobook',
}) => Track({
  'id': id,
  'slug': 'audio-$id',
  'title': title,
  'title_hi': title,
  'kind': kind,
  'audio_url': p.url,
  'artwork_url': artwork,
  'duration_sec': p.seconds,
  'artist': artist,
  'attribution': '$artist · $license',
  'license': license,
  'source_url': source.isNotEmpty ? source : p.source,
});

/// Stable track ids for audiobook parts (well above the catalogue's own ids).
int audioTrackId(String bookId, int index) {
  var h = 0;
  for (final c in bookId.codeUnits) {
    h = (h * 31 + c) % 50000;
  }
  return 2000000 + h * 1000 + index;
}

String hoursMinutes(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}
