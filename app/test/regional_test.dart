import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/holidays.dart';
import 'package:devalay/core/location.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/providers.dart';
import 'package:devalay/core/regional.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/core/wishes.dart';
import 'package:devalay/features/calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUpAll(initTestStorage);

  group('Amanta and Purnimanta', () {
    test('a Krishna paksha takes the next month in Purnimanta', () {
      // Ashwin Krishna (Amanta 6) is Kartika Krishna in North India; Shukla days keep their month.
      expect(shownMonth(MonthSystem.purnimanta, 6, krishna: true).index, 7);
      expect(shownMonth(MonthSystem.purnimanta, 6, krishna: false).index, 6);
      expect(shownMonth(MonthSystem.amanta, 6, krishna: true).index, 6);
      expect(shownMonth(MonthSystem.purnimanta, 11, krishna: true).index, 0);
    });

    test('Adhika Jyeshtha 2026 stays whole in Purnimanta', () {
      // Vaishakha Krishna (2-16 May 2026) is Jyeshtha; Adhika Jyeshtha keeps both halves.
      expect(shownMonth(MonthSystem.purnimanta, 1, krishna: true), (index: 2, adhika: false));
      expect(shownMonth(MonthSystem.purnimanta, 2, krishna: false, adhika: true), (index: 2, adhika: true));
      expect(shownMonth(MonthSystem.purnimanta, 2, krishna: true, adhika: true), (index: 2, adhika: true));
      expect(shownMonth(MonthSystem.purnimanta, 2, krishna: true), (index: 3, adhika: false));
    });

    test('defaults follow the language and Settings overrides them', () async {
      await Boxes.prefs.delete('month_system');
      expect(monthSystemFor('hi'), MonthSystem.purnimanta);
      expect(monthSystemFor('pa'), MonthSystem.purnimanta);
      expect(monthSystemFor('te'), MonthSystem.amanta);
      expect(monthSystemFor('en'), MonthSystem.amanta);
      await Boxes.prefs.put('month_system', 'purnimanta');
      expect(monthSystemFor('te'), MonthSystem.purnimanta);
      await Boxes.prefs.delete('month_system');
    });

    test('a month-summary day picks its paksha from the tithi', () {
      final day = {'lunar_month': 6, 'tithi_index': 20, 'paksha': 'Krishna', 'adhika': false};
      expect(shownMonthOf(MonthSystem.purnimanta, day), (index: 7, adhika: false));
      expect(shownMonthOf(MonthSystem.purnimanta, {'tithi_index': 3}), isNull);
    });
  });

  group('solar calendars', () {
    SolarDate at(String cal, String date, int month, int day) => SolarDate.of(cal, {
      'date': date,
      'solar': {
        cal: [month, day],
      },
    })!;

    test('13 Nov 2026 reads as Aippasi 27 and its era in each calendar', () {
      final ta = at('ta', '2026-11-13', 6, 27);
      expect(ta.label('en'), 'Aippasi 27');
      expect(ta.label('ta'), 'ஐப்பசி 27');
      expect(ta.era('en'), 'Parabhava');
      expect(at('ml', '2026-11-13', 6, 27).era('en'), 'Kollam Era 1202');
      expect(at('bn', '2026-11-13', 6, 27).era('en'), 'Bangabda 1433');
      expect(at('or', '2026-11-13', 6, 28).era('en'), isNull);
    });

    test('years turn at Chithirai, Chingam and Boishakh', () {
      // Before Medam/Chithirai (Panguni, March) and after (Chithirai, April).
      expect(at('ta', '2026-03-20', 11, 6).era('en'), 'Vishvavasu');
      expect(at('ta', '2026-04-14', 0, 1).era('en'), 'Parabhava');
      // Kollam 1201 runs to Karkidakam; Chingam 1 = 17 Aug 2026 begins 1202, still 1202 in January.
      expect(at('ml', '2026-08-16', 3, 31).kollamYear, 1201);
      expect(at('ml', '2026-08-17', 4, 1).kollamYear, 1202);
      expect(at('ml', '2027-01-10', 8, 26).kollamYear, 1202);
      // Bangabda 1432 until Choitro ends; Boishakh 1 = 15 Apr 2026 begins 1433.
      expect(at('bn', '2026-04-14', 11, 30).bangabda, 1432);
      expect(at('bn', '2026-04-15', 0, 1).bangabda, 1433);
      expect(at('bn', '2027-01-05', 8, 20).bangabda, 1433);
    });

    test('the extra calendar follows the language unless Settings says otherwise', () async {
      await Boxes.prefs.delete('solar_calendar');
      expect(solarCalendarFor('ta'), 'ta');
      expect(solarCalendarFor('bn'), 'bn');
      expect(solarCalendarFor('te'), isNull);
      await Boxes.prefs.put('solar_calendar', 'ml');
      expect(solarCalendarFor('te'), 'ml');
      await Boxes.prefs.put('solar_calendar', 'none');
      expect(solarCalendarFor('ta'), isNull);
      await Boxes.prefs.delete('solar_calendar');
    });
  });

  group('cities', () {
    test('every city has a unique id and Indian cities a state', () {
      expect(cities.map((c) => c.id).toSet().length, cities.length);
      for (final c in cities.where((c) => c.tz == 'Asia/Kolkata')) {
        expect(c.state, matches(RegExp(r'^[A-Z]{2}$')), reason: c.id);
      }
    });

    test('nearest city from a position', () {
      final (city, km) = nearestCity(17.43, 78.45); // Hyderabad, Banjara Hills
      expect(city.id, 'hyderabad');
      expect(km, lessThan(10));
      expect(nearestCity(11.02, 76.95).$1.id, 'coimbatore');
      expect(nearestCity(40.73, -74.0).$1.id, 'new-york');
    });
  });

  group('state holidays', () {
    final json = jsonDecode(File('assets/data/holidays.json').readAsStringSync()) as Map;
    final catalog = HolidayCatalog(json);

    test('the bundled file is well formed and every list names its source', () {
      expect(catalog.schema, HolidayCatalog.supportedSchema);
      expect(catalog.version, greaterThan(0));
      for (final MapEntry(key: state, value: lists) in catalog.lists.entries) {
        expect(state, matches(RegExp(r'^[A-Z]{2}$')));
        for (final l in lists) {
          expect(['public', 'bank'], contains(l.kind));
          expect(l.source, startsWith('https://'), reason: '$state ${l.year} ${l.kind}');
          expect(l.days, isNotEmpty);
          expect(l.days.every((d) => d.date.year == l.year), isTrue, reason: '$state ${l.year} ${l.kind}');
        }
      }
    });

    test('a day both lists name is one holiday, public and bank', () {
      final merged = HolidayCatalog({
        'schema': 1,
        'version': 1,
        'states': {
          'TG': {
            'lists': [
              {
                'year': 2026,
                'kind': 'bank',
                'source': 'https://rbi.org.in',
                'days': [
                  ['2026-01-15', 'Makara Sankranti/Pongal'],
                  ['2026-04-01', "Banks' closing of accounts"],
                ],
              },
              {
                'year': 2026,
                'kind': 'public',
                'source': 'https://telangana.gov.in',
                'days': [
                  ['2026-01-15', 'Sankranti'],
                ],
              },
            ],
          },
        },
      }).forYear('TG', 2026);
      expect(merged.length, 2);
      final sankranti = merged[DateTime(2026, 1, 15)]!;
      expect((sankranti.name, sankranti.public, sankranti.bank), ('Sankranti', true, true));
      expect(merged[DateTime(2026, 4, 1)]!.public, isFalse);
    });
  });

  testWidgets('the Tamil calendar shows solar dates and state holidays at phone width', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Hive writes real files, which fake-async test time never finishes.
    await tester.runAsync(() async {
      await Boxes.prefs.put('language', 'ta');
      await Boxes.prefs.put('city', 'chennai');
    });
    final now = DateTime.now();
    // A month summary whose solar month turns over on the 17th, as Tamil months do.
    List<Map> month(int year, int m) => [
      for (var d = 1; d <= DateUtils.getDaysInMonth(year, m); d++)
        {
          'date': '$year-${'$m'.padLeft(2, '0')}-${'$d'.padLeft(2, '0')}',
          'sunrise': '$year-${'$m'.padLeft(2, '0')}-${'$d'.padLeft(2, '0')}T06:10:00+05:30',
          'sunset': '$year-${'$m'.padLeft(2, '0')}-${'$d'.padLeft(2, '0')}T17:40:00+05:30',
          'lunar_month': 7,
          'adhika': false,
          'tithi_index': d % 30 + 1,
          'tithi': 'Panchami',
          'paksha': d % 30 + 1 > 15 ? 'Krishna' : 'Shukla',
          'nakshatra': 'Rohini',
          'solar': {
            'ta': d < 17 ? [6, d + 14] : [7, d - 16],
          },
        },
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthProvider.overrideWith((ref, q) async => month(q.year, q.month)),
          festivalsProvider.overrideWith((ref, y) async => const <Festival>[]),
          wishCatalogProvider.overrideWith((ref) => const Stream.empty()),
          holidayCatalogProvider.overrideWith((ref) => const Stream.empty()),
          stateHolidaysProvider.overrideWith(
            (ref, y) => {
              DateTime(now.year, now.month, 5): StateHoliday(DateTime(now.year, now.month, 5), 'Bhogi', public: true),
            },
          ),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const CalendarScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('ஐப்பசி'), findsWidgets);
    expect(find.textContaining('கார்த்திகை'), findsWidgets);
    await tester.runAsync(() async {
      await Boxes.prefs.delete('language');
      await Boxes.prefs.delete('city');
    });
  }, timeout: const Timeout(Duration(seconds: 90)));
}
