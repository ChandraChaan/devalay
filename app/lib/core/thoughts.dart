import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One verse for the thought of the day: the original text exactly as its source prints it, with a
/// short meaning in the reader's language and in English. assets/data/thoughts.json is built by
/// tool/thoughts/build_thoughts.py from texts checked against their sources (see CONTENT_LICENSES.md).
class Thought {
  Thought(this._j);
  final Map _j;

  String get text => '${_j['text']}';
  String get author => '${_j['author']}';
  String get authorNative => '${_j['author_native'] ?? _j['author']}';
  String get work => '${_j['work'] ?? ''}';
  String get ref => '${_j['ref'] ?? ''}';
  String get meaning => '${_j['meaning']}';
  String get meaningEn => '${_j['meaning_en']}';
  String get source => '${_j['source'] ?? ''}';
}

class Thoughts {
  Thoughts(Map j)
    : byLanguage = {
        for (final e in (j['languages'] as Map).entries)
          '${e.key}': [for (final t in (e.value as List).cast<Map>()) Thought(t)],
      };

  /// Verses per collection: an app language code, or "sa" for the Sanskrit subhashitas English
  /// readers get.
  final Map<String, List<Thought>> byLanguage;

  /// The collection shown to readers of [lang]: their own language's classics, Sanskrit
  /// subhashitas (with English meanings) for English and any language without its own.
  List<Thought> forLanguage(String lang) {
    final own = byLanguage[lang];
    if (lang != 'en' && own != null && own.isNotEmpty) return own;
    return byLanguage['sa'] ?? const [];
  }

  /// Today's verse for [lang]. Each collection rotates by date, one verse a day, in order.
  Thought? of(String lang, DateTime day) {
    final list = forLanguage(lang);
    if (list.isEmpty) return null;
    return list[dayNumber(day) % list.length];
  }

  /// Days since 1 January 2024, so the verse changes at local midnight.
  static int dayNumber(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2024)).inDays;
}

Future<Thoughts> loadThoughts() async =>
    Thoughts(jsonDecode(await rootBundle.loadString('assets/data/thoughts.json')) as Map);

final thoughtsProvider = FutureProvider<Thoughts>((ref) => loadThoughts());
