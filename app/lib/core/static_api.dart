import 'dart:math';

import 'location.dart';

/// Serverless mode: maps API requests onto the static files written by
/// backend/scripts/export_static.py, and answers the few POST endpoints
/// (search, AI status, Ask the Gita) on device. Keep in step with that script.
class StaticApi {
  static final _unsafe = RegExp(r'[^A-Za-z0-9.-]');

  /// '/tracks', {kind: aarti, page_size: 100} -> 'tracks/kind-aarti~page_size-100.json'.
  static String file(String path, Map<String, dynamic>? query) {
    final q = <String, String>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null) e.key: '${e.value}',
    };
    // Location-dependent files are exported per city, not per coordinate.
    if (q.containsKey('lat')) {
      final city = cities.where((c) => '${c.lat}' == q['lat'] && '${c.lon}' == q['lon']).firstOrNull ?? cities.first;
      q
        ..remove('lat')
        ..remove('lon')
        ..remove('tz')
        ..['city'] = city.id;
    }
    if ((path == '/home' || path == '/rashifal') && !q.containsKey('day')) q['day'] = isoDay(DateTime.now());
    final keys = q.keys.toList()..sort();
    final name = keys.isEmpty ? 'index' : keys.map((k) => '$k-${q[k]!.replaceAll(_unsafe, '_')}').join('~');
    return '${path.replaceAll(RegExp(r'^/+|/+$'), '')}/$name.json';
  }

  static String isoDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Mirrors GET /search over the exported index.
  static Map<String, dynamic> search(Map index, String q, int limit) {
    final lower = q.toLowerCase();
    bool en(Object? v) => '${v ?? ''}'.toLowerCase().contains(lower);
    bool raw(Object? v) => '${v ?? ''}'.contains(q);
    List pick(String key, bool Function(Map m) test) =>
        (index[key] as List).cast<Map>().where(test).take(limit).toList();
    return {
      'tracks': pick('tracks', (t) => en(t['title']) || raw(t['title_hi'])),
      'texts': pick('texts', (t) => en(t['title']) || raw(t['title_hi']) || raw(t['body'])),
      'books': pick('books', (b) => en(b['title']) || raw(b['title_hi'])),
      'wallpapers': pick('wallpapers', (w) => en(w['title'])),
      'verses': pick('verses', (v) => en(v['translation_en']) || raw(v['sanskrit'])),
    };
  }

  /// Mirrors app.services.ai.offline_status.
  static Map<String, dynamic> status(Map t, Map data) {
    final lang = data['language'] == 'hi' ? 'hi' : 'en';
    final deity = '${data['deity'] ?? 'general'}';
    final names = (t['deity_names'] as Map)[deity] ?? (t['deity_names'] as Map)['general'];
    final chant = (t['chants'] as Map)[deity] ?? (t['chants'] as Map)['general'];
    String clean(Object? v) => '${v ?? ''}'.replaceAll(RegExp(r'[\r\n\t<>{}]'), ' ').trim();
    final name = clean(data['name']);
    final festival = clean(data['festival']);
    final prefix = '${((t['occasion_prefix'] as Map)[lang] as Map)[data['occasion']] ?? ''}'
        .replaceAll('{name}', name.isEmpty ? '' : ' $name')
        .replaceAll('{festival}', festival.isNotEmpty ? festival : (lang == 'hi' ? 'पर्व' : 'festival'));
    final templates = List<String>.from((t['templates'] as Map)[lang] as List)..shuffle(Random());
    final tags = ['#${'${names[0]}'.replaceAll(' ', '')}', '#Bhakti', '#Devalay'];
    return {
      'options': [
        for (final tpl in templates.take(3))
          {
            'text':
                prefix + tpl.replaceAll('{deity}', '${names[lang == 'hi' ? 1 : 0]}').replaceAll('{chant}', '$chant'),
            'hashtags': tags,
          },
      ],
      'provider': 'offline',
      'remaining_today': null,
    };
  }

  /// Mirrors app.services.gita_search (BM25) plus the offline answer.
  static Map<String, dynamic> ask(Map index, String question, String language) {
    final stop = Set<String>.from(index['stopwords'] as List);
    final synonyms = (index['synonyms'] as Map).cast<String, List>();
    List<String> tokens(String text) => RegExp(
      r'[a-z]+',
    ).allMatches(text.toLowerCase()).map((m) => m[0]!).where((w) => w.length > 2 && !stop.contains(w)).toList();
    final verses = (index['verses'] as List).cast<Map>();
    final docs = [
      for (final v in verses)
        tokens(
          '${v['translation_en']}',
        ).fold<Map<String, int>>({}, (m, w) => m..update(w, (n) => n + 1, ifAbsent: () => 1)),
    ];
    final df = <String, int>{};
    for (final tf in docs) {
      for (final w in tf.keys) {
        df.update(w, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final n = docs.length;
    final avg = docs.fold<int>(0, (s, tf) => s + tf.values.fold(0, (a, b) => a + b)) / max(n, 1);
    final terms = {
      for (final t in tokens(question)) ...(synonyms[t]?.cast<String>() ?? [t]),
    };
    const k1 = 1.5, b = 0.75;
    final scored = <(double, Map)>[];
    for (var i = 0; i < n; i++) {
      final tf = docs[i];
      final length = max(tf.values.fold(0, (a, b) => a + b), 1);
      var score = 0.0;
      for (final term in terms) {
        final f = tf[term];
        if (f == null) continue;
        final idf = log(1 + (n - df[term]! + 0.5) / (df[term]! + 0.5));
        score += idf * f * (k1 + 1) / (f + k1 * (1 - b + b * length / avg));
      }
      if (score > 0) scored.add((score, verses[i]));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final top = scored.take(4).map((s) => s.$2).toList();
    String answer;
    if (top.isEmpty) {
      answer =
          'I could not find a verse that speaks directly to this. Try asking in other words, '
          "or read Chapter 2, which summarises the Gita's core teaching.";
    } else {
      final refs = top.map((v) => '${v['chapter']}.${v['verse']}').join(', ');
      final lead = language == 'hi'
          ? 'इन श्लोकों में आपके प्रश्न से जुड़ी शिक्षा है ($refs):'
          : 'These verses speak to your question ($refs):';
      final quoted = top.take(2).map((v) => '${v['chapter']}.${v['verse']}: ${v['translation_en']}').join('\n\n');
      answer = '$lead\n\n$quoted';
    }
    return {'answer': answer, 'verses': top, 'provider': 'offline', 'remaining_today': null};
  }
}
