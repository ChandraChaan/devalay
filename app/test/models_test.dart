import 'package:devalay/core/i18n.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Track parses API payload and keeps raw map for offline storage', () {
    final t = Track({
      'id': 7,
      'slug': 'gayatri',
      'title': 'Gayatri Mantra',
      'title_hi': 'गायत्री मंत्र',
      'kind': 'mantra',
      'deity_id': 3,
      'audio_url': 'https://x/y.mp3',
      'artwork_url': '',
      'duration_sec': 21,
      'artist': 'A',
      'text_slug': 'gayatri-mantra',
      'attribution': 'A · CC0',
      'license': 'CC0',
      'source_url': 'https://s',
      'is_premium': false,
      'tags': <String>[],
      'play_count': 0,
    });
    expect(t.id, 7);
    expect(t.textSlug, 'gayatri-mantra');
    expect(Track(t.raw).title, 'Gayatri Mantra');
  });

  test('Festival day counting ignores the time of day', () {
    final f = Festival({
      'slug': 'diwali',
      'kind': 'festival',
      'name': 'Diwali',
      'name_hi': 'दीपावली',
      'deity': 'lakshmi',
      'date': '2026-11-08',
      'major': true,
      'description': '',
    });
    expect(f.daysFrom(DateTime(2026, 11, 3, 23, 30)), 5);
    expect(f.daysFrom(DateTime(2026, 11, 8, 6)), 0);
  });

  test('Gita chapter parses nested verses', () {
    final c = GitaChapter({
      'number': 2,
      'name_sanskrit': 'सांख्ययोग',
      'name_translit': 'sāṃkhyayoga',
      'name_en': 'x',
      'summary': 's',
      'verse_count': 1,
      'verses': [
        {
          'chapter': 2,
          'verse': 47,
          'sanskrit': 'कर्मण्येवाधिकारस्ते',
          'transliteration': 't',
          'translation_en': 'e',
          'translation_author': 'Annie Besant',
        },
      ],
    });
    expect(c.verses.single.ref, '2.47');
  });

  test('hhmm shows the city wall-clock time from an offset timestamp', () {
    expect(hhmm('2026-11-03T06:34:24.059+05:30'), '6:34 AM');
    expect(hhmm('2026-11-03T17:34:41+05:30'), '5:34 PM');
    expect(hhmm('2026-11-03T00:05:00+05:30'), '12:05 AM');
    expect(hhmm('garbage'), '--');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 75)), '01:15');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('translations fall back to English then the key', () {
    expect(trLang('hi', 'mandir'), 'मंदिर');
    expect(trLang('en', 'mandir'), 'Mandir');
    expect(trLang('fr', 'mandir'), 'Mandir');
    expect(trLang('en', 'unknown_key'), 'unknown_key');
  });

  test('palette parses hex colours safely', () {
    expect(Palette.hex('#3949AB'), const Color(0xFF3949AB));
    expect(Palette.hex('nope'), Palette.saffron);
  });

  test('rashi list covers all twelve signs', () {
    expect(rashiList.length, 12);
    expect(rashiList.map((r) => r.$1).toSet().length, 12);
  });
}
