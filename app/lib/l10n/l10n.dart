/// Translations of the app's English text for every language other than English and Telugu/Hindi UI
/// copy (which stays at the call sites in t3). Each lib/l10n/<code>.dart file maps the English text to
/// its translation; tool/l10n/extract.py lists every string to translate. Entries with {0}, {1} are
/// templates for text built at runtime ("{0} festivals").
library;

import 'bn.dart';
import 'bn_content.dart';
import 'gu.dart';
import 'gu_content.dart';
import 'hi.dart';
import 'kn.dart';
import 'kn_content.dart';
import 'ml.dart';
import 'ml_content.dart';
import 'mr.dart';
import 'mr_content.dart';
import 'or.dart';
import 'or_content.dart';
import 'pa.dart';
import 'pa_content.dart';
import 'ta.dart';
import 'ta_content.dart';

/// UI strings and Panchang names (<code>.dart) plus festival wishes and the temple guide
/// (<code>_content.dart), per language.
const _tables = <String, Map<String, String>>{
  'hi': stringsHi,
  'bn': {...stringsBn, ...contentBn},
  'mr': {...stringsMr, ...contentMr},
  'ta': {...stringsTa, ...contentTa},
  'gu': {...stringsGu, ...contentGu},
  'kn': {...stringsKn, ...contentKn},
  'ml': {...stringsMl, ...contentMl},
  'or': {...stringsOr, ...contentOr},
  'pa': {...stringsPa, ...contentPa},
};

/// The table for [lang], or null (English, or a language without one).
Map<String, String>? tableFor(String lang) => _tables[lang];

final _templates = <String, List<(RegExp, String)>>{};
final _placeholder = RegExp(r'\{(\d+)\}');

List<(RegExp, String)> _templatesFor(String lang) => _templates.putIfAbsent(lang, () {
  final out = <(RegExp, String)>[];
  for (final e in (_tables[lang] ?? const <String, String>{}).entries) {
    if (!e.key.contains('{')) continue;
    // "{0} festivals" -> ^(.*?) festivals$, with the groups in placeholder order.
    final order = <int>[];
    final pattern = e.key.splitMapJoin(
      _placeholder,
      onMatch: (m) {
        order.add(int.parse(m[1]!));
        return '(.*?)';
      },
      onNonMatch: RegExp.escape,
    );
    // Translations name placeholders by number, so remember which group fills which.
    var translated = e.value;
    for (var g = 0; g < order.length; g++) {
      translated = translated.replaceAll('{${order[g]}}', '\u0000$g\u0000');
    }
    out.add((RegExp('^$pattern\$', dotAll: true), translated));
  }
  return out;
});

/// The translation of [en] into [lang], filling templates, or null when there is none.
String? translate(String lang, String en) {
  final table = _tables[lang];
  if (table == null) return null;
  final exact = table[en];
  if (exact != null) return exact;
  for (final (re, value) in _templatesFor(lang)) {
    final m = re.firstMatch(en);
    if (m == null) continue;
    return value.replaceAllMapped(RegExp('\u0000(\\d+)\u0000'), (g) => m[int.parse(g[1]!) + 1] ?? '');
  }
  return null;
}
