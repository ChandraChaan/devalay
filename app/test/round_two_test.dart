import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/audiobooks.dart';
import 'package:devalay/core/nakshatra_info.dart';
import 'package:devalay/core/translate.dart';
import 'package:devalay/core/wishes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 27 birth stars have a deity, planet, symbol and gana in three languages', () {
    expect(nakshatraInfo, hasLength(27));
    for (final n in nakshatraInfo) {
      for (final t in [n.deity, n.symbol, n.lord.name, n.gana.name]) {
        expect([t.$1, t.$2, t.$3].every((s) => s.isNotEmpty), isTrue);
      }
      expect(n.lord.mantra, startsWith('ॐ'));
    }
    // Spot checks against the standard table: Ashwini–Ketu, Rohini–Moon, Revati–Mercury.
    expect(nakshatraInfo[0].lord, Graha.ketu);
    expect(nakshatraInfo[3].lord, Graha.moon);
    expect(nakshatraInfo[26].lord, Graha.mercury);
    // The nine planets repeat in the same order three times.
    for (var i = 0; i < 9; i++) {
      expect(nakshatraInfo[i + 9].lord, nakshatraInfo[i].lord);
      expect(nakshatraInfo[i + 18].lord, nakshatraInfo[i].lord);
    }
  });

  test('translation cache keys are stable and differ by text and language', () {
    final a = Translation.cacheKey('Peace be with you', 'te');
    expect(Translation.cacheKey('Peace be with you', 'te'), a);
    expect(Translation.cacheKey('Peace be with you', 'hi'), isNot(a));
    expect(Translation.cacheKey('Peace be with you!', 'te'), isNot(a));
    expect(translatableLanguages.keys, containsAll(['te', 'hi', 'ta', 'kn']));
    expect(translatableNames.keys.toSet(), translatableLanguages.keys.toSet());
  });

  test('the new Telugu festivals are in the wishes catalogue and match API festival slugs', () {
    final catalog = WishCatalog(jsonDecode(File('assets/data/wishes.json').readAsStringSync()) as Map);
    final ids = catalog.festivals.map((f) => f.id).toSet();
    expect(ids, containsAll(['bathukamma', 'atla-taddi', 'vasant-panchami', 'guru-purnima', 'dhanteras']));
    final bathukamma = catalog.festivals.firstWhere((f) => f.id == 'bathukamma');
    expect(bathukamma.match, containsAll(['engili-pula-bathukamma', 'saddula-bathukamma']));
    expect(bathukamma.days, 9);
  });

  test('audiobooks: every part is an https stream, the Gita has 18 English chapters and Sanskrit 1-3', () {
    final lib = AudioLibrary(jsonDecode(File('assets/data/audiobooks.json').readAsStringSync()) as Map);
    expect(lib.books.length, greaterThanOrEqualTo(20));
    for (final b in lib.books) {
      expect(b.sections, isNotEmpty, reason: b.id);
      for (final s in b.sections) {
        expect(s.url, startsWith('https://'), reason: '${b.id} ${s.title}');
      }
    }
    for (var c = 1; c <= 18; c++) {
      expect(lib.gitaEnglish[c], isNotNull, reason: 'English chapter $c');
    }
    expect(lib.gitaSanskrit.keys.toSet(), {1, 2, 3});
    expect(lib.gitaSanskrit[2]!.length, 72);
    expect(lib.forBook('ramayan-griffith'), hasLength(6));
    expect(audioTrackId('lv-9324', 3), audioTrackId('lv-9324', 3));
    expect(audioTrackId('lv-9324', 3), isNot(audioTrackId('lv-1497', 3)));
  });
}
