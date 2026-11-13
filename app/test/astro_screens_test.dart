import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/gochara.dart';
import 'package:devalay/core/jyotish.dart';
import 'package:devalay/core/providers.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/jatakam.dart';
import 'package:devalay/features/matching.dart';
import 'package:devalay/features/rashifal.dart';
import 'package:devalay/features/shubha_muhurtham.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Object _load(String name) => jsonDecode(File('test/data/$name').readAsStringSync());

Widget _app(Widget child, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

// A birth on 15 August 1990, 10:30 in Hyderabad.
const _birth = {
  'name': 'Ravi',
  'local': '1990-08-15T10:30:00.000',
  'place': 'Hyderabad',
  'lat': 17.39,
  'lon': 78.49,
  'tz': 'Asia/Kolkata',
  'offset': null,
};

void main() {
  setUpAll(initTestStorage);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('marriage matching fills a side from a saved Jatakam', (tester) async {
    await tester.runAsync(() async {
      await Boxes.prefs.put('language', 'en');
      await Boxes.prefs.put('birth_profiles', [_birth]);
    });
    await phone(tester);
    await tester.pumpWidget(_app(const MatchingScreen()));
    await tester.tap(find.byIcon(Icons.person_search_rounded).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Ravi'), findsOneWidget);
    await tester.tap(find.text('Ravi'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 15 August 1990, 10:30, Hyderabad: Moon in Rohini, pada 3.
    expect(find.text('Rohini'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('Jatakam shows a saved birth and saves the birth star', (tester) async {
    await tester.runAsync(() async {
      await Boxes.prefs.put('language', 'en');
      await Boxes.prefs.put('birth_profiles', [_birth]);
      await Boxes.prefs.delete('birth_star');
    });
    await phone(tester);
    await tester.pumpWidget(_app(const JatakamScreen()));
    await tester.tap(find.text('Ravi'));
    await tester.pumpAndSettle();
    expect(find.text('Lagna'), findsWidgets);
    expect(find.textContaining('pada'), findsWidgets);
    final use = find.text('Use as my birth star and rashi');
    await tester.scrollUntilVisible(use, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(use);
    // Let both Hive writes reach the disk; each one finishes on the real clock.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(Boxes.prefs.get('birth_star'), isA<int>());
    expect(Boxes.prefs.get('rashi'), isNotNull);
    await tester.scrollUntilVisible(find.text('North Indian'), -300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('North Indian'));
    await tester.pumpAndSettle();
  });

  // The language is still English from the tests above; another Hive write here would wait on theirs.
  testWidgets('Shubha Muhurtham lists dates with windows', (tester) async {
    await phone(tester);
    final data = _load('muhurtham_hyderabad.json') as Map;
    final kinds = data['kinds'] as Map;
    await tester.pumpWidget(
      _app(
        const ShubhaMuhurthamScreen(kind: 'griha_pravesha'),
        overrides: [
          muhurthamProvider.overrideWith(
            (ref) async => {
              for (final k in muhurthamKinds) k: [for (final d in kinds[k] as List) MuhurthamDay(k, d as Map)],
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // The fixture is for early 2027; past dates are hidden, so this is either the list or the empty state.
    expect(find.textContaining('House warming'), findsWidgets);
    expect(find.textContaining('Rahu Kalam is left out'), findsOneWidget);
    await tester.tap(find.textContaining('Naming ceremony'));
    await tester.pumpAndSettle();
    expect(find.textContaining('at least four hours'), findsOneWidget);
  });

  testWidgets('Rashifal has weekly, monthly and yearly tabs', (tester) async {
    await phone(tester);
    final tx = Transits(_load('gochara_2026.json') as Map);
    await tester.pumpWidget(
      _app(
        const RashifalScreen(),
        overrides: [
          rashifalProvider.overrideWith((ref) async => <Map>[]),
          gocharaProvider.overrideWith((ref) async => tx),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yearly'), findsOneWidget);
    final tabs = DefaultTabController.of(tester.element(find.byType(TabBarView)));
    tabs.animateTo(3);
    await tester.pumpAndSettle();
    expect(find.textContaining('Jupiter'), findsWidgets);
    tabs.animateTo(1);
    await tester.pumpAndSettle();
    expect(find.textContaining('★'), findsWidgets);
  });
}
