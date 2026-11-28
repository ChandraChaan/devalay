import 'package:devalay/core/status_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final saturday = DateTime(2026, 11, 28, 9);
  const panchang = {
    'tithi': {'name': 'Chaturthi', 'paksha': 'Krishna'},
    'nakshatra': {'index': 7, 'name': 'Punarvasu'},
    'lunar_month': {'index': 7},
  };

  test('every verse has all three scripts and meanings', () {
    for (final v in verses) {
      for (final s in [v.te, v.hi, v.en, v.meaning.$1, v.meaning.$2, v.meaning.$3]) {
        expect(s.trim(), isNotEmpty, reason: v.id);
      }
      expect(v.te, matches(RegExp('[ఀ-౿]')), reason: '${v.id} Telugu');
      expect(v.hi, matches(RegExp('[ऀ-ॿ]')), reason: '${v.id} Devanagari');
    }
    expect(verses.map((v) => v.id).toSet().length, verses.length);
  });

  test("Saturday's status greets the day, picks Venkateswara and adds the Panchang", () {
    final s = composeStatus(lang: 'te', day: saturday, panchang: panchang, name: 'Ravi');
    expect(s.headline, 'శుభ శనివారం');
    expect(s.deity, 'venkateswara');
    expect(s.verse.deities, contains('venkateswara'));
    expect(s.panchang, 'కార్తీక బహుళ చవితి · పునర్వసు');
    expect(s.signature, '— Ravi');
    expect(s.chant, 'ఓం నమో వేంకటేశాయ');
  });

  test('the same inputs give the same status; Shuffle gives another verse', () {
    final a = composeStatus(lang: 'en', day: saturday);
    final b = composeStatus(lang: 'en', day: saturday);
    final c = composeStatus(lang: 'en', day: saturday, variant: 1);
    expect(a.verse.id, b.verse.id);
    expect(c.verse.id, isNot(a.verse.id));
  });

  test('a festival today is greeted', () {
    final s = composeStatus(
      lang: 'hi',
      day: saturday,
      festival: (slug: 'gita-jayanti', deity: 'krishna', en: 'Gita Jayanti', te: 'గీతా జయంతి', hi: 'गीता जयंती'),
    );
    expect(s.headline, contains('गीता जयंती'));
    expect(s.deity, 'krishna');
  });

  test('birthday wishes name the person and bless with Shatamanam', () {
    final s = composeStatus(lang: 'te', day: saturday, occasion: StatusOccasion.birthday, to: 'అమ్మ');
    expect(s.headline, contains('అమ్మ'));
    expect(s.verse.id, 'shatamanam');
  });

  test('the personal blessing follows Tarabalam', () {
    // Birth star Ashwini (0); today Bharani (2 in the API's 1-27) is the 2nd tara, Sampat: good.
    expect(personalBlessing(birthStar: 0, todayStar: 2, lang: 'en'), contains('good day'));
    // Today Ashwini again: Janma tara.
    expect(personalBlessing(birthStar: 0, todayStar: 1, lang: 'en'), contains('Janma'));
    // Krittika (3): Vipat, a careful day.
    expect(personalBlessing(birthStar: 0, todayStar: 3, lang: 'te'), contains('రక్ష'));
    expect(personalBlessing(birthStar: null, todayStar: 3, lang: 'te'), isNull);
  });
}
