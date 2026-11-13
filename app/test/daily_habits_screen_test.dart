import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/models.dart';
import 'package:devalay/core/pooja.dart';
import 'package:devalay/core/providers.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/core/thoughts.dart';
import 'package:devalay/features/pooja.dart';
import 'package:devalay/features/status_maker.dart';
import 'package:devalay/features/thought.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _pooja = PoojaGuides(jsonDecode(File('assets/data/pooja_guides.json').readAsStringSync()) as Map);
final _thoughts = Thoughts(jsonDecode(File('assets/data/thoughts.json').readAsStringSync()) as Map);

Widget _app(Widget child) => ProviderScope(
  overrides: [
    poojaGuidesProvider.overrideWith((ref) async => _pooja),
    thoughtsProvider.overrideWith((ref) async => _thoughts),
    wallpapersProvider.overrideWith((ref, deity) async => const <Wallpaper>[]),
  ],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: child),
  ),
);

void main() {
  setUpAll(initTestStorage);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('a pooja guide ticks samagri and remembers it, in Tamil', (tester) async {
    await tester.runAsync(() => Boxes.prefs.put('language', 'ta'));
    await phone(tester);
    await tester.pumpWidget(_app(const PoojaGuideScreen(id: 'daily')));
    await tester.pumpAndSettle();
    final guide = _pooja.byId('daily')!;
    expect(find.text(guide.title('ta')), findsOneWidget);
    expect(guide.title('ta'), isNot(guide.title('en')));

    await tester.tap(find.byType(Checkbox).first);
    // Let Hive finish writing on the real event loop.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(Boxes.prefs.get('pooja_samagri'), {
      'daily': [0],
    });
    // Mantras are shown in Tamil script, not Devanagari.
    final mantra = find.textContaining('வக்ரதுண்ட மஹாகாய');
    for (var i = 0; i < 20 && mantra.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    expect(mantra, findsWidgets);
    expect(find.textContaining('वक्रतुण्ड'), findsNothing);
    await tester.runAsync(() => Boxes.prefs.put('language', 'en'));
  });

  testWidgets('the guide list opens every guide', (tester) async {
    await tester.runAsync(() => Boxes.prefs.put('language', 'en'));
    await phone(tester);
    await tester.pumpWidget(_app(const PoojaGuidesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Satyanarayana Vratam'), findsOneWidget);
    for (final g in _pooja.guides) {
      await tester.pumpWidget(_app(PoojaGuideScreen(id: g.id)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: g.id);
    }
  });

  testWidgets('the thought of the day shows today\'s verse with both meanings', (tester) async {
    await tester.runAsync(() => Boxes.prefs.put('language', 'te'));
    await phone(tester);
    await tester.pumpWidget(_app(const SingleChildScrollView(child: ThoughtOfDayCard())));
    await tester.pumpAndSettle();
    final t = _thoughts.of('te', DateTime.now())!;
    expect(find.text('నేటి సూక్తి'), findsOneWidget);
    expect(find.text(t.meaning), findsOneWidget);
    await tester.tap(find.text('ఇంగ్లీషులో అర్థం'));
    await tester.pumpAndSettle();
    expect(find.text(t.meaningEn), findsOneWidget);
    await tester.runAsync(() => Boxes.prefs.put('language', 'en'));
  });

  testWidgets('the longest verse fits the share image', (tester) async {
    await phone(tester);
    final longest = _thoughts.byLanguage.values
        .expand((l) => l)
        .reduce((a, b) => a.text.length + a.meaning.length >= b.text.length + b.meaning.length ? a : b);
    await tester.pumpWidget(
      _app(
        StatusComposer(
          text: '${longest.text}\n\n${thoughtByline(longest)}',
          footnote: longest.meaning,
          deity: 'general',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
