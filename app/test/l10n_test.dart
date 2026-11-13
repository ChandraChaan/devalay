import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/i18n.dart';
import 'package:devalay/core/languages.dart';
import 'package:devalay/core/names.dart';
import 'package:devalay/core/script.dart';
import 'package:devalay/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every language must translate every string tool/l10n/extract.py finds, with the same
/// placeholders, so no screen falls back to English.
void main() {
  final strings = (jsonDecode(File('tool/l10n/strings.json').readAsStringSync()) as List).cast<Map>();
  final content = (jsonDecode(File('tool/l10n/strings_content.json').readAsStringSync()) as List).cast<Map>();
  final descriptions = (jsonDecode(File('tool/l10n/strings_descriptions.json').readAsStringSync()) as List).cast<Map>();
  final placeholder = RegExp(r'\{\d+\}');
  Set<String> marks(String s) => placeholder.allMatches(s).map((m) => m[0]!).toSet();

  for (final code in ['bn', 'mr', 'ta', 'gu', 'kn', 'ml', 'or', 'pa']) {
    test('$code translates every UI string and wish', () {
      final table = tableFor(code)!;
      final missing = [
        for (final e in [...strings, ...content, ...descriptions])
          if (!table.containsKey(e['en'])) e['en'],
      ];
      expect(missing, isEmpty, reason: '$code is missing ${missing.length}: ${missing.take(5)}');
      final broken = [
        for (final e in strings)
          if (!marks(table[e['en']]!).containsAll(marks('${e['en']}'))) e['en'],
      ];
      expect(broken, isEmpty, reason: '$code lost placeholders in $broken');
    });
  }

  for (final code in ['hi', 'te']) {
    test('$code has every festival and deity description', () {
      final table = tableFor(code)!;
      expect([
        for (final e in descriptions)
          if (!table.containsKey(e['en'])) e['en'],
      ], isEmpty);
    });
  }

  test('Hindi has every Panchang name the UI copy lacks', () {
    final table = tableFor('hi')!;
    final missing = [
      for (final e in strings)
        if ('${e['hi']}'.isEmpty && !table.containsKey(e['en'])) e['en'],
    ];
    expect(missing, isEmpty);
  });

  test('templates fill runtime values in the right order', () {
    expect(translate('kn', '8 festivals'), contains('8'));
    expect(translate('kn', '8 festivals'), isNot(contains('{')));
    expect(translate('en', 'Today'), isNull);
    expect(t3('ta', 'Today', 'आज', 'ఈరోజు'), isNot('Today'));
    expect(t3('xx', 'Today', 'आज', 'ఈరోజు'), 'Today');
  });

  test('every language has a native name and Material locale', () {
    expect(appLanguages.map((l) => l.code).toSet().length, appLanguages.length);
    expect(languageOf('kn').native, 'ಕನ್ನಡ');
    expect(languageOf('zz').code, 'en');
  });

  test('Devanagari goes into each script', () {
    expect(toIndicScript('kn', 'ॐ नमः शिवाय'), 'ಓಂ ನಮಃ ಶಿವಾಯ');
    expect(toIndicScript('ml', 'नमः'), 'നമഃ');
    expect(toIndicScript('gu', 'गणेश'), 'ગણેશ');
    expect(toIndicScript('bn', 'विष्णु'), 'বিষ্ণু');
    expect(toIndicScript('ta', 'भगवान'), 'பகவான');
    expect(toIndicScript('mr', 'गणेश'), 'गणेश');
    expect(scriptFor('te', 'राम'), 'రామ');
  });

  test('month names that are also nakshatras use the month form', () {
    expect(monthIn('kn', 2), 'ಜ್ಯೇಷ್ಠ');
    expect(monthIn('hi', 10), 'माघ');
    expect(nakshatraIn('kn', 'Jyeshtha'), isNot('ಜ್ಯೇಷ್ಠ'));
  });
}
