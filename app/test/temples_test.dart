import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/storage.dart';
import 'package:devalay/core/temples.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/temples.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

TempleCatalog _bundled() => TempleCatalog(jsonDecode(File('assets/data/temples.json').readAsStringSync()) as Map);

Widget _app(Widget child, TempleCatalog catalog, {TempleUpdates? updates}) => ProviderScope(
  overrides: [
    templeCatalogProvider.overrideWith((ref) => Stream.value(catalog)),
    templeUpdatesProvider.overrideWith((ref, path) async => updates),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

void main() {
  setUpAll(initTestStorage);
  setUp(() async {
    await Boxes.prefs.put('language', 'en');
    await Boxes.prefs.delete('temple_reminders');
  });

  group('bundled catalogue', () {
    final catalog = _bundled();

    test('has the schema this app reads and unique temples', () {
      expect(catalog.schema, TempleCatalog.supportedSchema);
      expect(catalog.version, greaterThan(0));
      expect(catalog.updated, isNotNull);
      final ids = catalog.temples.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(catalog.temples.where((t) => t.featured).map((t) => t.id), ['ttd']);
    });

    test('every temple is named in three languages and opens an HTTPS official site', () {
      for (final t in catalog.temples) {
        for (final lang in ['en', 'hi', 'te']) {
          expect(t.name(lang), isNotEmpty, reason: '${t.id} name $lang');
          expect(t.place(lang), isNotEmpty, reason: '${t.id} place $lang');
        }
        expect(t.state, isNotEmpty, reason: t.id);
        expect(isSafeBookingUrl(t.portalUrl), isTrue, reason: t.portalUrl);
        expect(Uri.parse(t.portalUrl).host, endsWith(t.portalHost), reason: '${t.id} shows the host it opens');
        expect(t.services, isNotEmpty, reason: t.id);
        final serviceIds = t.services.map((s) => s.id).toList();
        expect(serviceIds.toSet().length, serviceIds.length, reason: '${t.id} service ids');
        for (final s in t.services) {
          expect(s.name('en'), isNotEmpty, reason: '${t.id}/${s.id}');
          expect(s.summary('en'), isNotEmpty, reason: '${t.id}/${s.id}');
          expect(isSafeBookingUrl(t.urlFor(s)), isTrue, reason: t.urlFor(s));
        }
        for (final l in t.links) {
          expect(isSafeBookingUrl(l.url), isTrue, reason: l.url);
        }
      }
    });

    test('TTD lists its services in Telugu and Hindi too, with the usual release slots', () {
      final ttd = catalog.byId('ttd')!;
      expect(ttd.services.length, greaterThanOrEqualTo(15));
      for (final s in ttd.services) {
        expect(s.name('te'), isNot(s.name('en')), reason: s.id);
        expect(s.summary('hi'), isNot(s.summary('en')), reason: s.id);
      }
      final sed = ttd.services.firstWhere((s) => s.id == 'sed');
      expect((sed.release!.day, sed.release!.hour, sed.release!.ahead), (24, 10, 3));
      // Opening order through the month: e-Dip first, rooms last.
      expect(ttd.releases.first.id, 'edip');
      expect(ttd.releases.last.id, 'rooms');
      expect(ttd.steps('en'), isNotEmpty);
      expect(ttd.walkIn('te'), hasLength(3));
    });

    test('search matches names in any language, the place and the state', () {
      List<String> find(String q) => catalog.temples.where((t) => t.matches(q)).map((t) => t.id).toList();
      expect(find('tirupati'), ['ttd']);
      expect(find('శబరిమల'), ['sabarimala']);
      expect(find('वाराणसी'), ['kashi']);
      expect(find('kerala'), unorderedEquals(['sabarimala', 'guruvayur']));
      expect(find('  '), hasLength(catalog.temples.length));
    });
  });

  test('release slot finds the next opening and the month it is for', () {
    const slot = ReleaseSlot(day: 24, hour: 10, minute: 0, ahead: 3);
    final before = slot.next(DateTime.utc(2026, 11, 11, 9));
    expect(before, DateTime.utc(2026, 11, 24, 10));
    expect(slot.quotaMonth(before), DateTime.utc(2027, 2));
    // At the opening minute itself, and after it, the next one is a month later.
    expect(slot.next(DateTime.utc(2026, 11, 24, 10)), DateTime.utc(2026, 12, 24, 10));
    expect(slot.next(DateTime.utc(2026, 12, 25)), DateTime.utc(2027, 1, 24, 10));
    expect(slot.quotaMonth(DateTime.utc(2026, 12, 24, 10)), DateTime.utc(2027, 3));
  });

  test('release slot rejects days and hours that do not exist every month', () {
    expect(ReleaseSlot.parse({'day': 24, 'hour': 15})!.minute, 0);
    expect(ReleaseSlot.parse({'day': 31, 'hour': 10}), isNull);
    expect(ReleaseSlot.parse({'day': 1, 'hour': 10}), isNull);
    expect(ReleaseSlot.parse({'day': 24, 'hour': 24}), isNull);
    expect(ReleaseSlot.parse({'day': '24', 'hour': 10}), isNull);
    expect(ReleaseSlot.parse(null), isNull);
  });

  test('opening text in each language', () {
    const slot = ReleaseSlot(day: 23, hour: 15, minute: 0, ahead: 3);
    final now = DateTime.utc(2026, 11, 11);
    expect(nextOpening(slot, 'en', now: now), '23 Nov, 3:00 PM · for February 2027');
    expect(nextOpening(slot, 'hi', now: now, short: true), '23 नवंबर, 3:00 PM · फ़रवरी 2027 के लिए');
    expect(nextOpening(slot, 'te', now: now), '23 నవంబర్, 3:00 PM · ఫిబ్రవరి 2027 కోసం');
    expect(
      usualOpening(slot, 'en'),
      'Usually opens on the 23rd of each month at 3:00 PM IST, for visits 3 months later.',
    );
    expect(usualOpening(const ReleaseSlot(day: 21, hour: 10, minute: 0, ahead: 1), 'en'), contains('21st'));
    expect(usualOpening(slot, 'hi'), contains('23 तारीख'));
  });

  test('only HTTPS web addresses can be opened as a booking site', () {
    expect(isSafeBookingUrl('https://ttdevasthanams.ap.gov.in/home/dashboard'), isTrue);
    expect(isSafeBookingUrl('http://ttdevasthanams.ap.gov.in'), isFalse);
    expect(isSafeBookingUrl('javascript:alert(1)'), isFalse);
    expect(isSafeBookingUrl('intent://pay#Intent;scheme=upi;end'), isFalse);
    expect(isSafeBookingUrl('https://localhost'), isFalse);
    expect(isSafeBookingUrl(''), isFalse);
  });

  testWidgets('temple list features TTD and filters by search', (tester) async {
    await tester.pumpWidget(_app(const TemplesScreen(), _bundled()));
    await tester.pumpAndSettle();
    expect(find.text('Tirumala Tirupati Devasthanams'), findsOneWidget);
    expect(find.textContaining('See all'), findsOneWidget);
    expect(find.text('Shirdi Sai Baba Temple'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ayyappa');
    await tester.pumpAndSettle();
    expect(find.text('Sabarimala Ayyappa Temple'), findsOneWidget);
    expect(find.text('Shirdi Sai Baba Temple'), findsNothing);
    expect(find.text('Tirumala Tirupati Devasthanams'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No temple found'), findsOneWidget);
  });

  testWidgets('TTD page lists services and a service opens its booking sheet', (tester) async {
    await tester.pumpWidget(_app(const TempleScreen(id: 'ttd'), _bundled()));
    await tester.pumpAndSettle();
    expect(find.text('ttdevasthanams.ap.gov.in'), findsOneWidget);
    expect(find.text('Open official site'), findsOneWidget);
    expect(find.text('Usual booking dates'), findsOneWidget);
    expect(find.text('Show all 9 dates'), findsOneWidget);

    // With the dates list collapsed, the ₹300 ticket appears once, under Darshan.
    final service = find.text('Special Entry Darshan (₹300)');
    await tester.scrollUntilVisible(service, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(service);
    await tester.pumpAndSettle();
    await tester.tap(service);
    await tester.pumpAndSettle();
    expect(find.text('Book on official site'), findsOneWidget);
    expect(find.text('₹300 per person'), findsWidgets);
    expect(find.text('Remind me every month'), findsOneWidget);
    expect(find.textContaining('Usually opens on the 24th'), findsOneWidget);
  });

  test('announcements parse defensively and go stale after a week', () {
    final updates = TempleUpdates.parse({
      'fetched': '2026-11-11T18:40:00Z',
      'items': [
        {'title': ' Accommodation ', 'text': 'Quota for January-2027 opens 24.10.2026, 03:00 PM.', 'url': null},
        {'title': '', 'text': 'Selected list', 'url': 'https://ttdevasthanams.ap.gov.in/assets/list.pdf'},
        {'title': 'Unsafe link', 'text': 'Kept, without its link', 'url': 'http://example.com'},
        {'title': 'No text', 'text': '  '},
        'not an item',
      ],
    })!;
    expect(updates.items.map((u) => u.title), ['Accommodation', '', 'Unsafe link']);
    expect(updates.items[1].url, 'https://ttdevasthanams.ap.gov.in/assets/list.pdf');
    expect(updates.items[2].url, isNull);
    expect(updates.isFresh(DateTime.utc(2026, 11, 18, 18)), isTrue);
    expect(updates.isFresh(DateTime.utc(2026, 11, 18, 19)), isFalse);
    expect(TempleUpdates.parse({'items': []}), isNull, reason: 'no fetch time');
    expect(TempleUpdates.parse('oops'), isNull);
    expect(_bundled().byId('ttd')!.updatesPath, '/temples/ttd/updates');
    expect(_bundled().byId('shirdi')!.updatesPath, isNull);
  });

  testWidgets('TTD page shows the temple\'s own announcements when a fresh copy exists', (tester) async {
    final updates = TempleUpdates.parse({
      'fetched': DateTime.now().toUtc().toIso8601String(),
      'items': [
        for (final name in ['Accommodation', 'Special Entry Darshan', 'Seva E-Dip', 'SRIVANI Trust'])
          {'title': name, 'text': '$name quota for January-2027 opens soon.', 'url': null},
      ],
    });
    await tester.pumpWidget(_app(const TempleScreen(id: 'ttd'), _bundled(), updates: updates));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Show all 4 announcements'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Latest from the temple'), findsOneWidget);
    expect(find.text('Accommodation quota for January-2027 opens soon.'), findsOneWidget);
    expect(find.text('SRIVANI Trust quota for January-2027 opens soon.'), findsNothing);
    await tester.ensureVisible(find.text('Show all 4 announcements'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all 4 announcements'));
    await tester.pumpAndSettle();
    expect(find.text('SRIVANI Trust quota for January-2027 opens soon.'), findsOneWidget);
    expect(find.textContaining('from ttdevasthanams.ap.gov.in'), findsOneWidget);
  });

  testWidgets('without announcements the TTD page shows no empty section', (tester) async {
    await tester.pumpWidget(_app(const TempleScreen(id: 'ttd'), _bundled()));
    await tester.pumpAndSettle();
    expect(find.text('Latest from the temple'), findsNothing);
    expect(find.text('Usual booking dates'), findsOneWidget);
  });

  testWidgets('an unknown temple id shows a message, not an error', (tester) async {
    await tester.pumpWidget(_app(const TempleScreen(id: 'nowhere'), _bundled()));
    await tester.pumpAndSettle();
    expect(find.text('This temple is not listed yet'), findsOneWidget);
  });

  testWidgets('Telugu users see Telugu names', (tester) async {
    await tester.runAsync(() => Boxes.prefs.put('language', 'te'));
    await tester.pumpWidget(_app(const TemplesScreen(), _bundled()));
    await tester.pumpAndSettle();
    expect(find.text('తిరుమల తిరుపతి దేవస్థానములు'), findsOneWidget);
    expect(find.text('శబరిమల అయ్యప్ప ఆలయం'), findsOneWidget);
  });
}
