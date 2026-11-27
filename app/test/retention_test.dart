import 'package:devalay/app.dart';
import 'package:devalay/core/calendar_reminders.dart';
import 'package:devalay/core/home_widget_sync.dart';
import 'package:devalay/core/notifications.dart';
import 'package:devalay/core/retention.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/shell.dart';
import 'package:devalay/widgets/morning_panchang_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// The morning Panchang notification, the home-screen widget and the events that measure them.
void main() {
  setUpAll(initTestStorage);

  const day = {
    'date': '2026-11-19',
    'sunrise': '2026-11-19T06:24:00+05:30',
    'sunset': '2026-11-19T17:41:00+05:30',
    'tithi_index': 10,
    'lunar_month': 8,
    'nakshatra': 'Pushya',
  };

  test('morning message gives sunrise, sunset and the city the times are for', () {
    final m = panchangMessage('en', DateTime(2026, 11, 19), day, const [], const [], city: 'Hyderabad');
    expect(m.body, contains('🌅 Sunrise 6:24 AM · Sunset 5:41 PM · 📍 Hyderabad'));
    final te = panchangMessage('te', DateTime(2026, 11, 19), day, const [], const [], city: 'హైదరాబాద్');
    expect(te.title, contains('నేటి పంచాంగం'));
    expect(te.body, contains('సూర్యోదయం 6:24 AM'));
    expect(te.body, contains('రాహు కాలం'));
  });

  test('a day without sunset gets no sun line', () {
    final m = panchangMessage(
      'en',
      DateTime(2026, 11, 19),
      {'date': '2026-11-19', 'sunrise': '2026-11-19T06:24:00+05:30', 'tithi_index': 10, 'nakshatra': 'Pushya'},
      const [],
      const [],
    );
    expect(m.body, isNot(contains('Sunrise')));
  });

  test('widget day carries a compact sunrise and sunset line', () {
    final w = widgetDay('te', DateTime(2026, 11, 19), day, const [], const []);
    expect(w['sun'], '🌅 6:24 AM · 🌇 5:41 PM');
    expect(w['rahu'], isNotEmpty);
  });

  test('tapped reminders open their screen', () {
    expect(Notifications.routeFor(Notifications.panchangKind), '/panchang');
    expect(Notifications.routeFor(Notifications.festivalKind), '/panchang');
    expect(Notifications.routeFor(Notifications.prayerKind), '/listen');
    expect(Notifications.routeFor(Notifications.eventKind), '/calendar');
    expect(Notifications.routeFor('something-else'), isNull);
  });

  test('widget links name the widget without changing the screen they open', () {
    expect(widgetRoute(Uri.parse('devalay://panchang?w=panchang')), '/panchang');
    expect(widgetRoute(Uri.parse('devalay://calendar/day/2026-11-19?w=tithi')), '/calendar/day/2026-11-19');
    expect(widgetRoute(Uri.parse('devalay://calendar?w=countdown')), '/calendar');
  });

  testWidgets('screen views name pushed screens, not the tab underneath', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(path: '/panchang', builder: (_, _) => const Text('panchang')),
        GoRoute(path: '/gita/:chapter', builder: (_, _) => const Text('chapter')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(screenPattern(router.routerDelegate.currentConfiguration), '/home');
    router.push('/panchang');
    await tester.pumpAndSettle();
    expect(screenPattern(router.routerDelegate.currentConfiguration), '/panchang');
    router.push('/gita/2');
    await tester.pumpAndSettle();
    expect(screenPattern(router.routerDelegate.currentConfiguration), '/gita/:chapter');
  });

  test('a city nobody picked follows the language, not New Delhi', () async {
    await Boxes.prefs.delete('city');
    await Boxes.prefs.put('language', 'te');
    expect(Prefs.load(Boxes.prefs).cityId, 'hyderabad');
    expect(cityChosen, isFalse);
    await Boxes.prefs.put('language', 'ta');
    expect(Prefs.load(Boxes.prefs).cityId, 'chennai');
    await Boxes.prefs.put('language', 'hi');
    expect(Prefs.load(Boxes.prefs).cityId, 'delhi');
    await Boxes.prefs.put('city', 'vijayawada');
    await Boxes.prefs.put('language', 'te');
    expect(Prefs.load(Boxes.prefs).cityId, 'vijayawada');
    expect(cityChosen, isTrue);
    await Boxes.prefs.delete('city');
  });

  group('Home card', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const Scaffold(body: SingleChildScrollView(child: MorningPanchangCard())),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() async {
      await Boxes.prefs.put('language', 'en');
      await Boxes.prefs.put('onboarded', true);
      await Boxes.prefs.delete('panchang_daily');
      await Boxes.prefs.delete('city');
      await Boxes.prefs.delete(morningCardClosedKey);
    });

    testWidgets('offers the morning Panchang and names the city', (tester) async {
      await pump(tester);
      expect(find.text("Today's Panchang, every morning"), findsOneWidget);
      expect(find.text('Times for New Delhi'), findsOneWidget);
      expect(find.text('Turn on'), findsOneWidget);
    });

    testWidgets('is gone once the morning Panchang is on and the city chosen (no widget pinning in tests)', (
      tester,
    ) async {
      // Hive writes do real I/O, which a widget test's fake clock never completes.
      await tester.runAsync(() async {
        await Boxes.prefs.put('panchang_daily', true);
        await Boxes.prefs.put('city', 'vijayawada');
      });
      await pump(tester);
      expect(find.text("Today's Panchang, every morning"), findsNothing);
      expect(find.text('Turn on'), findsNothing);
    });

    testWidgets('stays closed after the user closes it', (tester) async {
      await pump(tester);
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.close_rounded));
        await Future<void>.delayed(const Duration(milliseconds: 200)); // let Hive write
      });
      await tester.pumpAndSettle();
      expect(find.text('Turn on'), findsNothing);
      expect(Boxes.prefs.get(morningCardClosedKey), isTrue);
      await pump(tester);
      expect(find.text('Turn on'), findsNothing);
    });
  });
}
