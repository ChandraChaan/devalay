import 'package:devalay/core/calendar_reminders.dart';
import 'package:devalay/core/events.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/muhurta.dart';
import 'package:devalay/core/providers.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/muhurta_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Map _day(String date, int tithi, int month, {bool adhika = false}) => {
  'date': date,
  'tithi_index': tithi,
  'lunar_month': month,
  'adhika': adhika,
};

void main() {
  setUpAll(initTestStorage);

  group('time helpers', () {
    test('wallClock keeps the city time and isoOffset reads the zone', () {
      final t = wallClock('2026-11-15T06:44:10+05:30');
      expect((t.isUtc, t.hour, t.minute), (true, 6, 44));
      expect(isoOffset('2026-11-15T06:44:10+05:30'), const Duration(hours: 5, minutes: 30));
      expect(isoOffset('2026-07-01T05:00:00-04:00'), const Duration(hours: -4));
      expect(clock(DateTime.utc(2026, 1, 1, 0, 5)), '12:05 AM');
      expect(clock(DateTime.utc(2026, 1, 1, 13, 30)), '1:30 PM');
    });
  });

  group('muhurta', () {
    // Chennai, Sunday 15 Nov 2026 (Drik Panchang): sunrise 06:44, sunset 17:28.
    final sunday = DateTime(2026, 11, 15);
    final rise = DateTime.utc(2026, 11, 15, 6, 44);
    final set = DateTime.utc(2026, 11, 15, 17, 28);
    final next = DateTime.utc(2026, 11, 16, 6, 44);

    test('Gowri Panchangam matches Drik Panchang for a Sunday', () {
      final g = gowri(sunday, rise, set, next);
      expect(g.length, 16);
      expect(g.take(8).map((p) => p.key), ['uthi', 'amirdha', 'rogam', 'laabam', 'dhanam', 'sugam', 'soram', 'visham']);
      expect(g.skip(8).map((p) => p.key), ['dhanam', 'sugam', 'soram', 'visham', 'uthi', 'amirdha', 'rogam', 'laabam']);
      // Drik: Amirdha 08:04–09:25, night Uthi 00:06–01:46.
      expect((hm(g[1].start), hm(g[1].end)), ('08:04', '09:25'));
      // (Drik's 01:46 uses sunrise to the second; this test's minute-rounded sunrise gives 01:45.)
      expect(hm(g[12].start), '00:06');
      expect(g[12].end.difference(DateTime.utc(2026, 11, 16, 1, 46)).inMinutes.abs(), lessThanOrEqualTo(1));
      expect(g.where((p) => p.night).length, 8);
    });

    test('every weekday has eight distinct Gowri periods by day and night', () {
      for (var i = 0; i < 7; i++) {
        final d = DateTime(2026, 11, 15 + i);
        final g = gowri(d, rise, set, next);
        expect(g.take(8).map((p) => p.key).toSet().length, 8, reason: '$d day');
        expect(g.skip(8).map((p) => p.key).toSet().length, 8, reason: '$d night');
      }
    });

    test('Choghadiya follows the classical order', () {
      final c = choghadiya(sunday, rise, set, next);
      expect(c.take(8).map((p) => p.key), ['udveg', 'char', 'labh', 'amrit', 'kaal', 'shubh', 'rog', 'udveg']);
      expect(c.skip(8).map((p) => p.key), ['shubh', 'amrit', 'char', 'rog', 'kaal', 'labh', 'udveg', 'shubh']);
      final monday = choghadiya(DateTime(2026, 11, 16), rise, set, next);
      expect(monday.take(8).map((p) => p.key), ['amrit', 'kaal', 'shubh', 'rog', 'udveg', 'char', 'labh', 'amrit']);
      expect(monday.skip(8).map((p) => p.key), ['char', 'rog', 'kaal', 'labh', 'udveg', 'shubh', 'amrit', 'char']);
      expect(c.first.start, rise);
      expect(c[7].end, set);
      expect(c.last.end, next);
    });

    test('Hora starts with the weekday lord and the next day carries on', () {
      final h = hora(sunday, rise, set, next);
      expect(h.length, 24);
      expect(h.first.key, 'sun');
      expect(h[12].key, 'jupiter');
      // The 25th hora would be Monday's first: the Moon.
      expect(horaPlanets[(horaPlanets.indexOf(h.last.key) + 1) % 7], 'moon');
      expect(hora(DateTime(2026, 11, 21), rise, set, next).first.key, 'saturn');
    });

    test('Rahu Kalam takes the right eighth of daylight', () {
      final r = DateTime.utc(2026, 1, 1, 6);
      final s = DateTime.utc(2026, 1, 1, 18);
      String span(DateTime day) {
        final (a, b) = rahuKalam(day, r, s);
        return '${hm(a)}-${hm(b)}';
      }

      expect(span(DateTime(2026, 11, 15)), '16:30-18:00'); // Sunday
      expect(span(DateTime(2026, 11, 16)), '07:30-09:00'); // Monday
      expect(span(DateTime(2026, 11, 17)), '15:00-16:30'); // Tuesday
      expect(span(DateTime(2026, 11, 18)), '12:00-13:30'); // Wednesday
      expect(span(DateTime(2026, 11, 19)), '13:30-15:00'); // Thursday
      expect(span(DateTime(2026, 11, 20)), '10:30-12:00'); // Friday
      expect(span(DateTime(2026, 11, 21)), '09:00-10:30'); // Saturday
    });

    test('auspicious yogas and holidays', () {
      expect(shubhYoga(DateTime(2026, 11, 19), 'Pushya'), 'guru-pushya');
      expect(shubhYoga(DateTime(2026, 11, 15), 'Pushya'), 'ravi-pushya');
      expect(shubhYoga(DateTime(2026, 11, 15), 'Hasta'), 'amrita-siddhi');
      expect(shubhYoga(DateTime(2026, 11, 16), 'Hasta'), isNull);
      expect(nationalHoliday(DateTime(2027, 1, 26)), 'republic-day');
      expect(nationalHoliday(DateTime(2027, 1, 27)), isNull);
      expect(lunarMonthLabel('te', 7), 'కార్తీకం');
    });
  });

  group('tithi events', () {
    test('tithiDays picks the first sunrise and handles a skipped tithi', () {
      final days = [
        _day('2026-11-01', 4, 7),
        _day('2026-11-02', 5, 7),
        _day('2026-11-03', 5, 7), // same tithi at two sunrises: first one counts
        _day('2026-11-04', 6, 7),
        _day('2026-11-05', 8, 7), // Saptami (7) skipped: it falls on 4 Nov
      ];
      expect(tithiDays(days, 7, 5), [DateTime(2026, 11, 2)]);
      expect(tithiDays(days, 7, 7), [DateTime(2026, 11, 4)]);
      expect(tithiDays(days, 8, 5), isEmpty);
    });

    test('adhika months are skipped', () {
      final days = [_day('2026-05-20', 5, 2, adhika: true), _day('2026-06-19', 5, 2)];
      expect(tithiDays(days, 2, 5), [DateTime(2026, 6, 19)]);
    });

    test('occurrences by repeat rule', () {
      final once = UserEvent(
        id: '1',
        title: 'Puja',
        kind: 'puja',
        date: DateTime(2026, 12, 1),
        repeat: EventRepeat.once,
      );
      expect(once.occurrencesIn(2026, const []), [DateTime(2026, 12, 1)]);
      expect(once.occurrencesIn(2027, const []), isEmpty);

      final leap = UserEvent(
        id: '2',
        title: 'Ravi',
        kind: 'birthday',
        date: DateTime(2024, 2, 29),
        repeat: EventRepeat.yearly,
      );
      expect(leap.occurrencesIn(2027, const []), [DateTime(2027, 2, 28)]);
      expect(leap.occurrencesIn(2028, const []), [DateTime(2028, 2, 29)]);
      expect(leap.occurrencesIn(2023, const []), isEmpty);

      final taddinam = UserEvent(
        id: '3',
        title: 'Taata',
        kind: 'remembrance',
        date: DateTime(2015, 11, 2),
        repeat: EventRepeat.tithi,
        tithi: 5,
        lunarMonth: 7,
      );
      final days = [_day('2026-11-01', 4, 7), _day('2026-11-02', 5, 7), _day('2026-11-03', 6, 7)];
      expect(taddinam.occurrencesIn(2026, days), [DateTime(2026, 11, 2)]);
      expect(taddinam.tithiLabel('en'), 'Kartika Shukla Panchami');
      expect(nextOccurrence(taddinam, DateTime(2026, 11, 2, 9), days, const []), DateTime(2026, 11, 2));
      expect(nextOccurrence(taddinam, DateTime(2026, 11, 3), days, const []), isNull);
    });

    test('json round trip', () {
      final e = UserEvent(
        id: 'x',
        title: 'Amma',
        kind: 'birthday',
        date: DateTime(1965, 8, 9),
        repeat: EventRepeat.tithi,
        tithi: 20,
        lunarMonth: 4,
        remind: false,
      );
      final back = UserEvent.fromJson(e.toJson())!;
      expect(
        (back.title, back.date, back.repeat, back.tithi, back.lunarMonth, back.remind),
        ('Amma', DateTime(1965, 8, 9), EventRepeat.tithi, 20, 4, false),
      );
      expect(UserEvent.fromJson({'id': 'bad'}), isNull);
    });

    test('tithi names', () {
      expect(tithiName('en', 15), 'Shukla Purnima');
      expect(tithiName('en', 30), 'Krishna Amavasya');
      expect(tithiName('en', 19), 'Krishna Chaturthi');
      expect(tithiName('te', 1), 'శుక్ల పక్షం పాడ్యమి');
    });
  });

  test('morning Panchang message', () {
    final m = panchangMessage(
      'en',
      DateTime(2026, 11, 19),
      {
        'date': '2026-11-19',
        'sunrise': '2026-11-19T06:00:00+05:30',
        'sunset': '2026-11-19T18:00:00+05:30',
        'tithi_index': 10,
        'lunar_month': 8,
        'nakshatra': 'Pushya',
      },
      [
        Festival({'slug': 'ekadashi-x', 'kind': 'ekadashi', 'name': 'Ekadashi', 'date': '2026-11-19'}),
      ],
      [
        UserEvent(
          id: '1',
          title: "Amma's birthday",
          kind: 'birthday',
          date: DateTime(2026, 11, 19),
          repeat: EventRepeat.yearly,
        ),
      ],
    );
    expect(m.title, contains("Today's Panchang"));
    expect(m.body, contains('Margashirsha Shukla Dashami'));
    expect(m.body, contains('Rahu Kalam: 1:30 PM – 3:00 PM'));
    expect(m.body, contains('Guru Pushya'));
    expect(m.body, contains('🙏 Ekadashi'));
    expect(m.body, contains("🎂 Amma's birthday"));
  });

  testWidgets('Muhurta card switches between Choghadiya, Hora and Gowri', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [monthProvider.overrideWith((ref, q) async => const <Map>[])],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: MuhurtaTimings(
                data: {
                  'date': '2026-11-15',
                  'sunrise': '2026-11-15T06:44:00+05:30',
                  'sunset': '2026-11-15T17:28:00+05:30',
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Udveg'), findsWidgets);
    await tester.tap(find.text('Gowri'));
    await tester.pumpAndSettle();
    expect(find.text('Udyogam'), findsOneWidget);
    expect(find.text('8:04 AM – 9:25 AM'), findsOneWidget);
    await tester.tap(find.text('Hora'));
    await tester.pumpAndSettle();
    expect(find.text('Sun'), findsWidgets);
    await tester.tap(find.text('Night'));
    await tester.pumpAndSettle();
    expect(find.text('Jupiter'), findsWidgets);
  });
}
