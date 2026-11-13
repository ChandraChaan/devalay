import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/matching.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _app() => ProviderScope(
  child: MaterialApp(theme: buildTheme(Brightness.light), home: const MatchingScreen()),
);

Future<void> _pick(WidgetTester tester, Finder field, String item) async {
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestStorage);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('scores a match once both stars are picked', (tester) async {
    await tester.runAsync(() => Boxes.prefs.put('language', 'en'));
    await phone(tester);
    await tester.pumpWidget(_app());
    expect(find.text('Choose both birth stars to see the match'), findsOneWidget);

    final stars = find.byType(DropdownButton<int>);
    await _pick(tester, stars.at(0), 'Rohini');
    await _pick(tester, stars.at(2), 'Pushya');

    expect(find.text('26 / 36'), findsOneWidget);
    expect(find.text('Very good match'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('consult your family'), 300);
    expect(find.textContaining('consult your family'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('10 Porutham'), -300);
    await tester.tap(find.text('10 Porutham'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/ 10'), findsOneWidget);
    expect(find.text('Rajju ★'), findsOneWidget);
  });

  testWidgets('a known pada fixes the rashi of a split nakshatra', (tester) async {
    await tester.runAsync(() => Boxes.prefs.put('language', 'en'));
    await phone(tester);
    await tester.pumpWidget(_app());
    final ints = find.byType(DropdownButton<int>);
    await _pick(tester, ints.at(0), 'Krittika');
    // Krittika is mostly in Vrishabha; pada 1 is in Mesha.
    expect(find.text('♉ Vrishabha (Taurus)'), findsOneWidget);
    await _pick(tester, find.byType(DropdownButton<int?>).first, '1');
    expect(find.text('♈ Mesha (Aries)'), findsOneWidget);
  });

  testWidgets('Telugu users see Telugu', (tester) async {
    await tester.runAsync(() => Boxes.prefs.put('language', 'te'));
    await phone(tester);
    await tester.pumpWidget(_app());
    expect(find.text('వివాహ పొంతన'), findsOneWidget);
    final stars = find.byType(DropdownButton<int>);
    await _pick(tester, stars.at(0), 'అశ్విని');
    await _pick(tester, stars.at(2), 'అశ్విని');
    expect(find.text('28 / 36'), findsOneWidget);
    expect(find.textContaining('నాడీ దోషం'), findsOneWidget);
    await tester.runAsync(() => Boxes.prefs.put('language', 'en'));
  });
}
