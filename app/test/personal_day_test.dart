import 'package:devalay/core/muhurta.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/personal_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Hyderabad, 26 Nov 2026 (from the published panchang): the Moon rises in Vrishabha and enters
/// Mithuna at 07:15; Mrigashira gives way to Ardra at 17:47.
final _nov26 = <String, dynamic>{
  'date': '2026-11-26',
  'moon_rashi': 'Vrishabha',
  'moon_rashis': [
    {'index': 2, 'name': 'Vrishabha', 'starts': null, 'ends': '2026-11-26T07:15:02.120000+05:30'},
    {'index': 3, 'name': 'Mithuna', 'starts': '2026-11-26T07:15:02.120000+05:30', 'ends': null},
  ],
  'nakshatra': [
    {'index': 5, 'name': 'Mrigashira', 'starts': null, 'ends': '2026-11-26T17:47:19.291782+05:30'},
    {'index': 6, 'name': 'Ardra', 'starts': '2026-11-26T17:47:19.291782+05:30', 'ends': null},
  ],
};

void main() {
  group('day timelines', () {
    test('the span in force at a moment, or the first at sunrise', () {
      final spans = daySpans(_nov26['nakshatra']);
      expect(spans.map((s) => s.index), [5, 6]);
      expect(spanAt(spans, null), 0);
      expect(spanAt(spans, DateTime.parse('2026-11-26T09:00:00+05:30')), 0);
      expect(spanAt(spans, DateTime.parse('2026-11-26T22:43:00+05:30')), 1);
      expect(spanAt(const [], DateTime(2026)), 0);
    });

    test('malformed entries are skipped', () {
      expect(daySpans(null), isEmpty);
      expect(daySpans('x'), isEmpty);
      final spans = daySpans([
        {'index': 'two'},
        'junk',
        {'index': 4, 'starts': 7, 'ends': '2026-11-26T07:15:00+05:30'},
      ]);
      expect(spans, [(index: 4, starts: null, ends: '2026-11-26T07:15:00+05:30')]);
    });

    test("the Moon's signs, with older data falling back to the sign at sunrise", () {
      expect(moonSignSpans(_nov26).map((s) => s.index), [2, 3]);
      expect(moonSignSpans({'moon_rashi': 'Vrishabha'}), [(index: 2, starts: null, ends: null)]);
      expect(moonSignSpans({'moon_rashi': 'Pluto'}), isEmpty);
      expect(
        moonSignSpans({
          'moon_rashis': [
            {'index': 13},
          ],
          'moon_rashi': 'Meena',
        }).single.index,
        12,
      );
    });
  });

  group('Is today good for you?', () {
    setUpAll(initTestStorage);

    Future<void> show(WidgetTester tester, Map data, DateTime now, {String lang = 'en'}) async {
      await tester.runAsync(() async {
        await Boxes.prefs.put('language', lang);
        await Boxes.prefs.put('rashi', 'vrishabha');
        await Boxes.prefs.put('birth_star', 3); // Rohini
      });
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                child: PersonalBalam(data: data, now: now),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    // The verdict's shimmer runs on a timer; unmount and let it finish before the test ends.
    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }

    // The report: Vrishabha rashi, read at night on 26 Nov. The Moon was in Mithuna (2nd house),
    // but the card showed the sunrise sign (1st house) all day.
    testWidgets('tonight it counts from the sign the Moon is in now', (tester) async {
      await show(tester, _nov26, DateTime.parse('2026-11-26T22:43:00+05:30'));
      expect(tester.takeException(), isNull);
      expect(find.text('2nd house'), findsOneWidget);
      expect(find.text('Until 7:15 AM: 1st house (Good)'), findsOneWidget);
      // Rohini to Ardra is the 3rd tara (Vipat); until 5:47 PM it was Mrigashira, Sampat.
      expect(find.text('Vipat'), findsOneWidget);
      expect(find.text('Until 5:47 PM: Sampat (Good)'), findsOneWidget);
      await close(tester);
    });

    testWidgets('early morning shows the sunrise values and when they change', (tester) async {
      await show(tester, _nov26, DateTime.parse('2026-11-26T06:40:00+05:30'));
      expect(find.text('1st house'), findsOneWidget);
      expect(find.text('From 7:15 AM: 2nd house (Avoid)'), findsOneWidget);
      expect(find.text('From 5:47 PM: Vipat (Avoid)'), findsOneWidget);
      await close(tester);
    });

    testWidgets('another day starts from sunrise', (tester) async {
      await show(tester, _nov26, DateTime.parse('2026-11-25T22:00:00+05:30'));
      expect(find.text('1st house'), findsOneWidget);
      expect(find.text('From 7:15 AM: 2nd house (Avoid)'), findsOneWidget);
      await close(tester);
    });

    testWidgets('data from before 1.5.5 still shows a single value', (tester) async {
      final old = Map.of(_nov26)..remove('moon_rashis');
      await show(tester, old, DateTime.parse('2026-11-26T22:43:00+05:30'));
      expect(tester.takeException(), isNull);
      expect(find.text('1st house'), findsOneWidget);
      expect(find.textContaining('7:15 AM'), findsNothing);
      await close(tester);
    });

    for (final lang in ['hi', 'te', 'ta', 'bn', 'gu', 'kn', 'ml', 'mr', 'or', 'pa']) {
      testWidgets('the change line is translated in $lang', (tester) async {
        await show(tester, _nov26, DateTime.parse('2026-11-26T22:43:00+05:30'), lang: lang);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Until'), findsNothing);
        expect(find.textContaining('7:15 AM'), findsOneWidget);
        await close(tester);
      });
    }
  });
}
