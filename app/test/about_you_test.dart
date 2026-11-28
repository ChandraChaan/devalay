import 'package:devalay/core/about_you.dart';
import 'package:devalay/core/admin_stats.dart';
import 'package:devalay/core/age.dart';
import 'package:devalay/core/calendar_reminders.dart';
import 'package:devalay/core/jatakam.dart';
import 'package:devalay/core/languages.dart';
import 'package:devalay/core/location.dart';
import 'package:devalay/core/muhurta.dart';
import 'package:devalay/core/profile_sync.dart';
import 'package:devalay/core/profiles.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _hyderabad = cities.firstWhere((c) => c.id == 'hyderabad');

AboutYou _ravi({int? minutes = 10 * 60 + 30}) => AboutYou(
  name: 'Ravi Kumar',
  gender: Gender.male,
  birthDate: DateTime(1990, 8, 15),
  birthMinutes: minutes,
).copyWith(city: () => _hyderabad);

void main() {
  setUpAll(initTestStorage);

  group('age', () {
    final today = DateTime(2026, 11, 28);
    test('whole years, counting the birthday itself', () {
      expect(ageOn(DateTime(2008, 11, 28), today), 18);
      expect(ageOn(DateTime(2008, 11, 29), today), 17);
      expect(ageOn(DateTime(2027, 1, 1), today), isNull);
    });
    test('groups and minors', () {
      expect(ageGroupFor(DateTime(2008, 11, 29), today), 'under18');
      expect(ageGroupFor(DateTime(2008, 11, 28), today), '18-24');
      expect(ageGroupFor(DateTime(1990, 8, 15), today), '35-44');
      expect(ageGroupFor(DateTime(1950, 1, 1), today), '65+');
      expect(AboutYou(birthDate: DateTime(2012, 5, 5)).isMinorOn(today), isTrue);
      expect(_ravi().isMinorOn(today), isFalse);
      // No date of birth: not treated as a minor, no group.
      expect(AboutYou.empty.isMinorOn(today), isFalse);
      expect(AboutYou.empty.ageGroupOn(today), isNull);
    });
  });

  group('birthday', () {
    test('29 February is kept on 28 February in other years', () {
      final p = AboutYou(birthDate: DateTime(2000, 2, 29));
      expect(p.isBirthday(DateTime(2027, 2, 28)), isTrue);
      expect(p.isBirthday(DateTime(2028, 2, 28)), isFalse);
      expect(p.isBirthday(DateTime(2028, 2, 29)), isTrue);
      expect(p.nextBirthday(DateTime(2027, 3, 1)), DateTime(2028, 2, 29));
    });
    test('today counts as the next birthday; no date means none', () {
      final p = _ravi();
      expect(p.nextBirthday(DateTime(2026, 8, 15, 20)), DateTime(2026, 8, 15));
      expect(p.nextBirthday(DateTime(2026, 8, 16)), DateTime(2027, 8, 15));
      expect(AboutYou.empty.nextBirthday(DateTime(2026, 1, 1)), isNull);
      expect(AboutYou(birthDate: DateTime(2030, 1, 1)).isBirthday(DateTime(2026, 1, 1)), isFalse);
    });
    test('wish names the user when known', () {
      expect(birthdayWish('en', 'Ravi').$1, '🎂 Happy birthday, Ravi!');
      expect(birthdayWish('en', '').$1, '🎂 Happy birthday!');
      expect(birthdayWish('te', 'రవి').$1, contains('రవి'));
      expect(_ravi().firstName, 'Ravi');
    });
  });

  group('stars', () {
    test('with a birth time they match the Jatakam screen', () {
      final p = _ravi();
      final chart = BirthProfile(
        name: '',
        local: DateTime(1990, 8, 15, 10, 30),
        place: 'Hyderabad',
        lat: _hyderabad.lat,
        lon: _hyderabad.lon,
        zone: _hyderabad.tz,
      ).chart;
      final s = p.computeStars()!;
      expect(s.rashi, chart.moonRashi);
      expect(s.nakshatra, chart.nakshatra);
      expect(s.pada, chart.pada);
      expect(s.lagna, chart.lagnaRashi);
      expect(p.birth!.local, DateTime(1990, 8, 15, 10, 30));
    });

    test('without a time: no lagna or pada, and the Moon only when it stays put all day', () {
      final s = _ravi(minutes: null).computeStars()!;
      expect(s.lagna, isNull);
      expect(s.pada, isNull);
      Jatakam at(int h, int m) => BirthProfile(
        name: '',
        local: DateTime(1990, 8, 15, h, m),
        place: '',
        lat: _hyderabad.lat,
        lon: _hyderabad.lon,
        zone: _hyderabad.tz,
      ).chart;
      final start = at(0, 0), end = at(23, 59);
      expect(s.nakshatra, start.nakshatra == end.nakshatra ? start.nakshatra : isNull);
      expect(s.rashi, start.moonRashi == end.moonRashi ? start.moonRashi : isNull);
    });

    test('nothing without a date or place; set-by-hand stars are kept', () {
      expect(AboutYou(birthDate: DateTime(1990, 1, 1)).computeStars(), isNull);
      expect(const AboutYou(name: 'x').copyWith(city: () => _hyderabad).computeStars(), isNull);
      final byHand = _ravi().copyWith(rashi: () => 3, nakshatra: () => 7, starsByHand: true);
      expect(byHand.withComputedStars().nakshatra, 7);
      expect(byHand.withComputedStars().rashi, 3);
    });
  });

  group('storage', () {
    test('round trip', () {
      final p = _ravi().withComputedStars().copyWith(gotra: 'Bharadwaja', updated: DateTime.utc(2026, 11, 28, 5));
      expect(AboutYou.fromMap(p.toMap()), p);
      expect(AboutYou.fromMap(null), AboutYou.empty);
      expect(AboutYou.fromMap(const {}).isEmpty, isTrue);
    });

    test('malformed data is dropped, never thrown', () {
      final p = AboutYou.fromMap({
        'name': 'x' * 200,
        'gender': 'robot',
        'dob': 'yesterday',
        'tob': 5000,
        'placeId': 'atlantis',
        'lat': 'north',
        'lon': double.nan,
        'rashi': 12,
        'nakshatra': -1,
        'pada': 5,
        'lagna': '3',
        'byHand': 'yes',
        'updated': 42,
      });
      expect(p.name.length, 60);
      expect(p.gender, isNull);
      expect(p.birthDate, isNull);
      expect(p.birthMinutes, isNull);
      expect(p.placeId, isNull);
      expect(p.lat, isNull);
      expect([p.rashi, p.nakshatra, p.pada, p.lagna], everyElement(isNull));
      expect(p.starsByHand, isFalse);
      expect(p.updated, isNull);
    });

    test('a listed city without saved coordinates takes them from the list', () {
      final p = AboutYou.fromMap({'placeId': 'hyderabad'});
      expect(p.hasPlace, isTrue);
      expect(p.lat, _hyderabad.lat);
      expect(p.zone, _hyderabad.tz);
    });

    test('the statistics copy has the birth time but no coordinates', () {
      final p = _ravi().withComputedStars().copyWith(name: 'A' * 70, gotra: 'Kashyapa');
      final m = p.toInstall(DateTime(2026, 11, 28));
      expect(m['tob'], 10 * 60 + 30);
      expect(m.keys, isNot(contains('lat')));
      expect(m.keys, isNot(contains('lon')));
      expect(m['n'], 'A' * 40);
      expect(m['g'], 'm');
      expect(m['dob'], '1990-08-15');
      expect(m['ag'], '35-44');
      expect(m['bp'], 'Hyderabad');
      expect(m['go'], 'Kashyapa');
      expect(m['l'], isA<int>());
      expect(AboutYou.empty.toInstall(DateTime(2026)), isEmpty);
    });
  });

  group('provider', () {
    test('saving points the app at the stars; removing takes them back', () async {
      await Boxes.prefs.delete('birth_star');
      await Boxes.prefs.delete('rashi');
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(aboutYouProvider.notifier).save(_ravi());
      final saved = c.read(aboutYouProvider);
      expect(saved.nakshatra, isNotNull);
      expect(saved.updated, isNotNull);
      expect(c.read(prefsProvider).birthStar, saved.nakshatra);
      expect(c.read(prefsProvider).rashi, rashiNames[saved.rashi!].toLowerCase());
      expect(AboutYou.fromMap(Boxes.prefs.get(AboutYouNotifier.key) as Map), saved);

      // The Home birth-star sheet changing the star marks the profile's stars as set by hand.
      final other = (saved.nakshatra! + 5) % 27;
      await c.read(aboutYouProvider.notifier).starsChanged(nakshatra: other, rashi: rashiOfStar(other));
      expect(c.read(aboutYouProvider).nakshatra, other);
      expect(c.read(aboutYouProvider).pada, isNull);
      expect(c.read(aboutYouProvider).starsByHand, isTrue);

      await c.read(aboutYouProvider.notifier).clear(stars: true);
      expect(c.read(aboutYouProvider).isEmpty, isTrue);
      expect(Boxes.prefs.containsKey(AboutYouNotifier.key), isFalse);
    });
  });

  group('admin copy', () {
    test('install profile reads what the phone sends and works out the age from the date', () {
      final row = InstallRow.fromMap('u1', {
        'profile': {
          'n': 'Ravi',
          'g': 'm',
          'dob': '2001-11-01',
          'tob': 6 * 60 + 5,
          'ag': '18-24',
          'r': 4,
          's': 9,
          'l': 2,
          'bp': 'Hyderabad',
        },
      });
      expect(row.profile.birthTime, '06:05');
      expect(row.profile.ageGroupOn(DateTime(2026, 11, 28)), '25-34');
      expect(row.profile.genderLabel, 'Male');
      expect(row.profile.rashiLabel, 'Simha');
      expect(row.profile.nakshatraLabel, 'Magha');
      expect(row.profile.lagnaLabel, 'Mithuna');
      final junk = InstallRow.fromMap('u2', {
        'profile': {'g': 'x', 'r': 40, 'ag': 'old', 'dob': 7, 'tob': 2000},
      });
      expect(junk.profile.isEmpty, isTrue);
      expect(junk.profile.ageGroupOn(DateTime(2026)), '');
      expect(InstallRow.fromMap('u3', {'profile': 'nope'}).profile.isEmpty, isTrue);
    });

    test('users filter by age group, gender, rashi and name', () {
      final now = DateTime(2026, 11, 28);
      final rows = [
        InstallRow.fromMap('a1', {
          'profile': {'n': 'Lakshmi', 'g': 'f', 'dob': '1995-01-01', 'r': 0},
        }),
        InstallRow.fromMap('b2', {
          'profile': {'n': 'Ravi', 'g': 'm', 'ag': '45-54', 'r': 4},
        }),
        InstallRow.fromMap('c3', const {}),
      ];
      List<String> ids(UserFilter f) => [for (final r in f.apply(rows, now: now)) r.uid];
      expect(ids(const UserFilter(ageGroup: '25-34')), ['a1']);
      expect(ids(const UserFilter(ageGroup: '45-54')), ['b2']);
      expect(ids(const UserFilter(gender: 'Female')), ['a1']);
      expect(ids(const UserFilter(rashi: 'Simha')), ['b2']);
      expect(ids(const UserFilter(query: 'laksh')), ['a1']);
      expect(const UserFilter(gender: 'Male').any, isTrue);
    });
  });

  group('morning Panchang', () {
    final day = {
      'date': '2026-11-19',
      'sunrise': '2026-11-19T06:00:00+05:30',
      'sunset': '2026-11-19T18:00:00+05:30',
      'tithi_index': 10,
      'lunar_month': 8,
      'nakshatra': 'Pushya',
    };

    test('greets by name and adds the day verdict with Chandrabalam', () {
      final moon = moonRashiAt('2026-11-19T06:00:00+05:30', _hyderabad.lat, _hyderabad.lon)!;
      expect(moon, inInclusiveRange(0, 11));
      final m = panchangMessage(
        'en',
        DateTime(2026, 11, 19),
        day,
        const [],
        const [],
        birthStar: 0,
        rashi: 0,
        name: 'Ravi',
        city: 'Hyderabad',
        at: (_hyderabad.lat, _hyderabad.lon),
      );
      expect(m.title, startsWith('🌅 Good morning, Ravi · '));
      final tara = tarabalam(0, nakshatraNames.indexOf('Pushya'));
      final chandra = chandrabalam(0, moon);
      expect(m.body, contains('🙏 ${personalVerdict('en', tara.quality, chandra.quality)}'));
      expect(m.body, contains('Chandrabalam: ${ordinal('en', chandra.house)}'));
    });

    test('without a name or moon sign it reads as before', () {
      final m = panchangMessage('en', DateTime(2026, 11, 19), day, const [], const [], birthStar: 0);
      expect(m.title, contains("Today's Panchang"));
      expect(m.body, isNot(contains('Chandrabalam')));
      expect(moonRashiAt('not a time', 0, 0), isNull);
      expect(rashiIndex('simha'), 4);
      expect(rashiIndex('pluto'), isNull);
    });
  });

  group('screen', () {
    Future<void> phone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400 * 3, 860 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    for (final l in appLanguages) {
      testWidgets('About you shows the saved stars in ${l.code}', (tester) async {
        await tester.runAsync(() async {
          await Boxes.prefs.put('language', l.code);
          await Boxes.prefs.put(AboutYouNotifier.key, _ravi().withComputedStars().toMap());
        });
        await phone(tester);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(theme: buildTheme(Brightness.light), home: const ProfileScreen()),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Ravi Kumar'), findsOneWidget);
        final star = _ravi().computeStars()!.nakshatra!;
        expect(find.textContaining(nakshatraLabel(l.code, star)), findsWidgets);
      });
    }

    testWidgets('typing a name enables Save, which keeps it', (tester) async {
      await tester.runAsync(() async {
        await Boxes.prefs.put('language', 'en');
        await Boxes.prefs.delete(AboutYouNotifier.key);
      });
      tester.view.physicalSize = const Size(400 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: buildTheme(Brightness.light), home: const ProfileScreen()),
        ),
      );
      final save = find.ancestor(of: find.text('Save'), matching: find.byWidgetPredicate((w) => w is FilledButton));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Sita');
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.runAsync(() async {
        await container.read(aboutYouProvider.notifier).save(container.read(aboutYouProvider).copyWith(name: 'Sita'));
      });
      expect(container.read(aboutYouProvider).name, 'Sita');
      expect(container.read(aboutYouProvider).firstName, 'Sita');
    });
  });
}
