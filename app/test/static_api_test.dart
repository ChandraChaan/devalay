import 'package:devalay/core/location.dart';
import 'package:devalay/core/static_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('static file names match backend/scripts/export_static.py', () {
    expect(StaticApi.file('/deities', null), 'deities/index.json');
    expect(StaticApi.file('/tracks/7', const {}), 'tracks/7/index.json');
    expect(
      StaticApi.file('/tracks', {'page_size': 100, 'kind': 'aarti,mantra', 'deity': null}),
      'tracks/kind-aarti_mantra~page_size-100.json',
    );
    final mumbai = cities.firstWhere((c) => c.id == 'mumbai');
    expect(
      StaticApi.file('/panchang/month', {...mumbai.query, 'year': 2026, 'month': 11}),
      'panchang/month/city-mumbai~month-11~year-2026.json',
    );
    expect(
      StaticApi.file('/festivals', {...mumbai.query, 'year': 2026, 'include_recurring': true}),
      'festivals/city-mumbai~include_recurring-true~year-2026.json',
    );
    expect(StaticApi.file('/home', cities.first.query), startsWith('home/city-delhi~day-'));
    expect(
      StaticApi.file('/rashifal', {'lang': 'hi'}),
      matches(RegExp(r'^rashifal/day-\d{4}-\d\d-\d\d~lang-hi\.json$')),
    );
  });

  final index = {
    'stopwords': ['the', 'and', 'what'],
    'synonyms': {
      'anger': ['anger', 'wrath'],
    },
    'verses': [
      {
        'chapter': 2,
        'verse': 62,
        'translation_en': 'From attachment arises desire, and from desire anger.',
        'sanskrit': '',
      },
      {'chapter': 2, 'verse': 63, 'translation_en': 'From wrath comes delusion.', 'sanskrit': ''},
      {'chapter': 9, 'verse': 22, 'translation_en': 'I carry what they lack.', 'sanskrit': ''},
    ],
    'tracks': [
      {'title': 'Om Jai Jagdish Hare', 'title_hi': 'ॐ जय जगदीश हरे'},
    ],
    'texts': <Map>[],
    'books': <Map>[],
    'wallpapers': <Map>[],
  };

  test('Ask the Gita ranks verses on device', () {
    final r = StaticApi.ask(index, 'How do I control anger?', 'en');
    expect((r['verses'] as List).map((v) => '${v['chapter']}.${v['verse']}'), unorderedEquals(['2.62', '2.63']));
    expect(r['answer'], contains('These verses speak to your question'));
  });

  test('search matches English and Devanagari titles', () {
    expect((StaticApi.search(index, 'jagdish', 5)['tracks'] as List).length, 1);
    expect((StaticApi.search(index, 'जगदीश', 5)['tracks'] as List).length, 1);
    expect((StaticApi.search(index, 'wrath', 5)['verses'] as List).length, 1);
  });

  test('offline status uses exported templates', () {
    final t = {
      'deity_names': {
        'general': ['Bhagwan', 'भगवान'],
        'hanuman': ['Hanuman Ji', 'हनुमान जी'],
      },
      'chants': {'general': 'हरि ॐ', 'hanuman': 'जय बजरंगबली'},
      'templates': {
        'en': ['A {deity} {chant}', 'B {deity}', 'C {deity}', 'D {deity}'],
        'hi': ['{deity}'],
      },
      'occasion_prefix': {
        'en': {'birthday': 'Happy birthday{name}! '},
        'hi': <String, String>{},
      },
    };
    final r = StaticApi.status(t, {'deity': 'hanuman', 'occasion': 'birthday', 'language': 'en', 'name': 'Asha'});
    final options = (r['options'] as List).cast<Map>();
    expect(options, hasLength(3));
    expect(options.every((o) => (o['text'] as String).startsWith('Happy birthday Asha! ')), isTrue);
    expect(options.first['hashtags'], contains('#HanumanJi'));
  });
}
