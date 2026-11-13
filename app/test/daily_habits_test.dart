import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/languages.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/names.dart';
import 'package:devalay/core/panchang_voice.dart';
import 'package:devalay/core/pooja.dart';
import 'package:devalay/core/thoughts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The thought of the day, the Panchang read aloud and the pooja guides.
void main() {
  final thoughts = Thoughts(jsonDecode(File('assets/data/thoughts.json').readAsStringSync()) as Map);
  final pooja = PoojaGuides(jsonDecode(File('assets/data/pooja_guides.json').readAsStringSync()) as Map);

  group('thought of the day', () {
    test('every language has its own collection; English reads Sanskrit', () {
      for (final l in appLanguages) {
        final list = thoughts.forLanguage(l.code);
        expect(list.length, greaterThanOrEqualTo(50), reason: l.code);
      }
      expect(thoughts.forLanguage('en'), same(thoughts.byLanguage['sa']));
      expect(thoughts.forLanguage('te'), same(thoughts.byLanguage['te']));
      expect(thoughts.forLanguage('xx'), same(thoughts.byLanguage['sa']));
    });

    test('every verse has a meaning in its language and in English, and a source', () {
      for (final e in thoughts.byLanguage.entries) {
        final texts = <String>{};
        for (final t in e.value) {
          expect(t.text.trim(), isNotEmpty);
          expect(t.meaning.trim(), isNotEmpty, reason: '${e.key}: ${t.text}');
          expect(t.meaningEn.trim(), isNotEmpty, reason: '${e.key}: ${t.text}');
          expect(t.author.trim(), isNotEmpty);
          expect(t.source, startsWith('https://'), reason: '${e.key}: ${t.text}');
          expect(texts.add(t.text), isTrue, reason: 'duplicate in ${e.key}: ${t.text}');
        }
      }
    });

    test('rotates one verse a day and wraps around', () {
      final day = DateTime(2026, 11, 13);
      final list = thoughts.forLanguage('ta');
      expect(thoughts.of('ta', day), isNot(same(thoughts.of('ta', day.add(const Duration(days: 1))))));
      expect(thoughts.of('ta', day), same(thoughts.of('ta', day.add(Duration(days: list.length)))));
      expect(thoughts.of('ta', DateTime(2026, 11, 13, 23, 59)), same(thoughts.of('ta', day)));
    });
  });

  group('pooja guides', () {
    test('every guide has items, steps and known mantras in English, Hindi and Telugu', () {
      expect(pooja.guides.map((g) => g.id), [
        'daily',
        'satyanarayana',
        'varalakshmi',
        'vinayaka-chavithi',
        'diwali-lakshmi',
        'maha-shivaratri',
        'ekadashi',
        'pradosham',
      ]);
      for (final g in pooja.guides) {
        for (final lang in ['en', 'hi', 'te']) {
          expect(g.title(lang), isNotEmpty);
          expect(g.when(lang), isNotEmpty);
          expect(g.samagri(lang), everyElement(isNotEmpty));
          for (final s in g.steps) {
            expect(s.title(lang), isNotEmpty);
            expect(s.text(lang), isNotEmpty);
          }
        }
        expect(g.samagriCount, greaterThan(5));
        expect(g.steps.length, greaterThan(5));
        expect(g.steps.where((s) => s.mantra != null), isNotEmpty, reason: g.id);
        for (final s in g.steps) {
          if (s.mantra case final m?) {
            expect(m.sanskrit, matches(RegExp('[ऀ-ॿ]')));
            expect(m.meaning('te'), isNotEmpty);
          }
        }
      }
      // Hindi and Telugu are written out, not translated through the tables.
      expect(pooja.byId('daily')!.title('te'), 'నిత్య పూజ');
      expect(pooja.byId('daily')!.title('ta'), isNot('Daily puja'));
    });

    Festival festival(String slug, String kind) => Festival({
      'slug': slug,
      'kind': kind,
      'name': slug,
      'name_hi': '',
      'deity': '',
      'date': '2026-11-08',
      'major': true,
      'description': '',
    });

    test('festivals link to their guide', () {
      expect(pooja.forFestival(festival('diwali', 'festival'))?.id, 'diwali-lakshmi');
      expect(pooja.forFestival(festival('ekadashi-2026-11-01', 'ekadashi'))?.id, 'ekadashi');
      expect(pooja.forFestival(festival('pradosh-2026-11-03', 'pradosh'))?.id, 'pradosham');
      expect(pooja.forFestival(festival('ganesh-chaturthi', 'festival'))?.id, 'vinayaka-chavithi');
      expect(pooja.forFestival(festival('holi', 'festival')), isNull);
    });
  });

  group('Panchang read aloud', () {
    setUpAll(initDates);

    final panchang = {
      'tithi': [
        {'paksha': 'Shukla', 'name': 'Tritiya', 'ends': '2026-11-13T18:05:00+05:30'},
      ],
      'nakshatra': [
        {'name': 'Rohini', 'index': 4, 'ends': '2026-11-14T02:40:00+05:30'},
      ],
      'sunrise': '2026-11-13T06:12:00+05:30',
      'sunset': '2026-11-13T17:41:00+05:30',
      'rahu_kaal': {'starts': '2026-11-13T10:30:00+05:30', 'ends': '2026-11-13T11:56:00+05:30'},
    };

    test('reads the day, tithi, nakshatra, sun times and Rahu Kalam', () {
      final lines = daySpeech('en', DateTime(2026, 11, 13), panchang: panchang);
      expect(lines.first, 'Friday, 13 November');
      expect(lines.join(' '), contains('Tithi: Shukla Tritiya, until 6:05 PM'));
      expect(lines.join(' '), contains('Nakshatra: Rohini, until 2:40 AM'));
      expect(lines.join(' '), contains('Rahu Kaal: from 10:30 AM to 11:56 AM'));
    });

    test('speaks times with the part of day in Indian languages, with no placeholders left', () {
      for (final l in appLanguages.where((l) => l.code != 'en')) {
        final text = daySpeech(l.code, DateTime(2026, 11, 13), panchang: panchang).join(' ');
        expect(text, isNot(contains('{')), reason: l.code);
        expect(text, isNot(contains('AM')), reason: l.code);
        expect(text, contains('10:30'), reason: l.code);
      }
      expect(spokenTime('hi', 18, 5), 'शाम 6:05');
      expect(spokenTime('te', 6, 12), 'ఉదయం 6:12');
    });

    test('falls back to the month summary when the full panchang is missing', () {
      final lines = daySpeech(
        'en',
        DateTime(2026, 11, 13),
        summary: {
          'tithi_index': 3,
          'nakshatra': 'Rohini',
          'sunrise': '2026-11-13T06:12:00+05:30',
          'sunset': '2026-11-13T17:41:00+05:30',
        },
      );
      expect(lines.join(' '), contains('Rohini'));
      expect(lines.join(' '), contains('Rahu Kaal: from'));
    });

    test('every app language has a text-to-speech locale', () {
      for (final l in appLanguages) {
        expect(ttsLocales[l.code], endsWith('-IN'));
      }
    });
  });
}
