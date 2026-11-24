import 'package:devalay/core/languages.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/day_guide_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map _day(String date, {int tithi = 2, int nakshatra = 4}) => {
  'date': date,
  'tithi': [
    {'index': tithi, 'name': 'Dwitiya', 'paksha': 'Shukla', 'ends': '${date}T18:05:00+05:30'},
  ],
  'nakshatra': [
    {'index': nakshatra, 'name': 'Rohini', 'ends': '${date}T20:00:00+05:30'},
  ],
  'rahu_kaal': [
    {'starts': '${date}T13:30:00+05:30', 'ends': '${date}T15:00:00+05:30'},
  ],
  'abhijit_muhurta': {'starts': '${date}T11:52:00+05:30', 'ends': '${date}T12:40:00+05:30'},
};

void main() {
  setUpAll(initTestStorage);

  Future<void> pump(WidgetTester tester, Map data, {String lang = 'en'}) async {
    await tester.runAsync(() => Boxes.prefs.put('language', lang));
    tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(child: DayGuideCard(data: data)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('English: direction, remedy, good, avoid and best time', (tester) async {
    // Tuesday 24 Nov 2026: Disha Shool north, remedy jaggery.
    await pump(tester, _day('2026-11-24', tithi: 4, nakshatra: 19));
    expect(find.text("Today's guidance"), findsOneWidget);
    expect(find.textContaining('towards the North'), findsOneWidget);
    expect(find.textContaining('eat a little jaggery before leaving'), findsOneWidget);
    expect(find.textContaining('Tuesday (Mars)'), findsOneWidget);
    expect(find.textContaining('Rikta tithi'), findsOneWidget);
    expect(find.textContaining('nakshatra is sharp'), findsOneWidget);
    expect(find.textContaining('Rahu Kaal 1:30 PM – 3:00 PM'), findsOneWidget);
    expect(find.textContaining('Abhijit Muhurta 11:52 AM – 12:40 PM'), findsOneWidget);
  });

  testWidgets('no Abhijit on Wednesday; every weekday has its own direction', (tester) async {
    const expected = {
      '2026-11-23': 'East', // Monday
      '2026-11-24': 'North',
      '2026-11-25': 'North',
      '2026-11-26': 'South',
      '2026-11-27': 'West',
      '2026-11-28': 'East',
      '2026-11-29': 'West', // Sunday
    };
    for (final e in expected.entries) {
      await pump(tester, _day(e.key));
      expect(find.textContaining('towards the ${e.value}'), findsOneWidget, reason: e.key);
      expect(find.textContaining('Abhijit Muhurta'), e.key == '2026-11-25' ? findsNothing : findsOneWidget);
    }
  });

  testWidgets('every tithi and nakshatra renders without errors', (tester) async {
    for (var t = 1; t <= 30; t++) {
      await pump(tester, _day('2026-11-24', tithi: t, nakshatra: (t - 1) % 27 + 1));
      expect(tester.takeException(), isNull, reason: 'tithi $t');
      expect(find.text("Today's guidance"), findsOneWidget);
    }
  });

  testWidgets('every app language is translated, none falls back to English', (tester) async {
    for (final l in appLanguages.where((l) => l.code != 'en')) {
      await pump(tester, _day('2026-11-24', tithi: 30, nakshatra: 10), lang: l.code);
      expect(tester.takeException(), isNull, reason: l.code);
      for (final english in ["Today's guidance", 'Avoid setting out', 'Good for', 'Better to avoid', 'Amavasya:']) {
        expect(find.textContaining(english), findsNothing, reason: '${l.code}: "$english" not translated');
      }
    }
  });

  testWidgets('missing or malformed panchang data never throws', (tester) async {
    final bad = <Map>[
      {},
      {'date': 'not a date'},
      {'date': '2026-11-24'},
      {'date': '2026-11-24', 'tithi': 'x', 'nakshatra': 7, 'rahu_kaal': 'x', 'abhijit_muhurta': []},
      {
        'date': '2026-11-24',
        'tithi': [
          {'index': '4'},
        ],
        'nakshatra': [
          {'index': 99},
        ],
        'rahu_kaal': [
          {'starts': null},
        ],
        'abhijit_muhurta': {'starts': 'garbage', 'ends': 'garbage'},
      },
      {
        'date': '2026-11-24',
        'tithi': [
          {'index': 4.0},
        ],
        'nakshatra': <Map>[],
      },
    ];
    for (final d in bad) {
      await pump(tester, d);
      expect(tester.takeException(), isNull, reason: '$d');
    }
  });
}
