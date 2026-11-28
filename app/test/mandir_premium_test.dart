import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/billing.dart';
import 'package:devalay/core/languages.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/perks.dart';
import 'package:devalay/core/providers.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/temples.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/mandir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_fakes.dart';
import 'helpers.dart';

/// The Mandir's Premium decorations, dakshina button and support card. The shrine images go
/// through the image cache, whose plugins don't exist in tests, so these tests only pump (never
/// let real async run) and seed Hive without awaiting: Hive updates its memory at once.
void main() {
  setUpAll(() async {
    await initTestStorage();
    await Boxes.prefs.put('language', 'en');
  });

  final catalog = TempleCatalog(jsonDecode(File('assets/data/temples.json').readAsStringSync()) as Map);
  Deity deity(int id, String slug) =>
      Deity({'id': id, 'slug': slug, 'name': slug, 'image_url': 'https://example.org/$slug.jpg', 'color': '#FF8800'});

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, FakeStore store, [MemoryCache? cache]) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...billingOverrides(store, cache),
          deitiesProvider.overrideWith((ref) async => [deity(1, 'ganesha'), deity(2, 'shiva')]),
          templeCatalogProvider.overrideWith((ref) => Stream.value(catalog)),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.dark), home: const MandirScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('every decoration draws with Premium, and the free look without', (tester) async {
    Boxes.stats.put('mandir_streak', 1);
    for (final d in MandirDecor.values) {
      Boxes.prefs.put('mandir_decor', d.name);
      await open(
        tester,
        FakeStore(owned: [purchase(Products.premiumYearly, PurchaseStatus.purchased)]),
        cachedPremium(),
      );
      expect(tester.takeException(), isNull, reason: d.name);
      expect(find.text('Dakshina'), findsOneWidget);
      expect(find.text('Decorate'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
    Boxes.prefs.put('mandir_decor', MandirDecor.deepotsava.name);
    await open(tester, FakeStore());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Deepotsava lamps fit a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(960, 1920); // 320 x 640 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Boxes.prefs.put('mandir_decor', MandirDecor.deepotsava.name);
    await open(tester, FakeStore(owned: [purchase(Products.premiumYearly, PurchaseStatus.purchased)]), cachedPremium());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the dakshina button opens both ways to give', (tester) async {
    await open(tester, FakeStore());
    await tester.tap(find.text('Dakshina'));
    await settle(tester);
    expect(find.text('Offer dakshina'), findsOneWidget);
    expect(find.text('At a temple'), findsOneWidget);
    expect(find.text('TTD · Tirumala · e-Hundi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the decoration sheet crowns Premium looks and sends them to Premium', (tester) async {
    Boxes.prefs.put('mandir_decor', MandirDecor.classic.name);
    await open(tester, FakeStore());
    await tester.tap(find.text('Decorate'));
    await settle(tester);
    expect(find.text('Decorate your Mandir'), findsOneWidget);
    expect(find.text('👑 decorations come with Premium.'), findsOneWidget);
    expect(find.text('👑'), findsNWidgets(MandirDecor.values.where((d) => d.premium).length));
    await tester.tap(find.text('Classic'));
    await settle(tester);
    expect(Perks.decor, MandirDecor.classic);
    expect(find.text('Decorate your Mandir'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('after a week of darshan the support card shows once and closes', (tester) async {
    final yesterday = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 1));
    Boxes.stats.put('mandir_last', yesterday.toIso8601String());
    Boxes.stats.put('mandir_streak', 6);
    Boxes.stats.delete('support_prompt_at');
    Boxes.stats.delete('support_gift_at');
    await open(tester, FakeStore());
    expect(find.textContaining('7 days of darshan in a row'), findsOneWidget);
    expect(Boxes.stats.get('support_prompt_at'), isNotNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await settle(tester);
    expect(find.textContaining('days of darshan in a row'), findsNothing);
    await tester.pumpWidget(const SizedBox());

    // Next visit: not again for 60 days.
    await open(tester, FakeStore());
    expect(find.textContaining('days of darshan in a row'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Premium members never see the support card', (tester) async {
    final yesterday = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 1));
    Boxes.stats.put('mandir_last', yesterday.toIso8601String());
    Boxes.stats.put('mandir_streak', 20);
    Boxes.stats.delete('support_prompt_at');
    await open(
      tester,
      FakeStore(owned: [purchase(Products.premiumMonthly, PurchaseStatus.purchased)]),
      cachedPremium(),
    );
    expect(find.textContaining('days of darshan in a row'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Mandir, dakshina and decoration sheets fit in all 11 languages', (tester) async {
    Boxes.stats.put('support_prompt_at', DateTime.now().toIso8601String());
    for (final l in appLanguages) {
      Boxes.prefs.put('language', l.code);
      await open(tester, FakeStore());
      expect(tester.takeException(), isNull, reason: 'Mandir in ${l.code}');
      await tester.tap(find.text('🪙'));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'dakshina in ${l.code}');
      await tester.pumpWidget(const SizedBox());
      await open(tester, FakeStore());
      await tester.tap(find.text('✨'));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'decorations in ${l.code}');
      await tester.pumpWidget(const SizedBox());
    }
    Boxes.prefs.put('language', 'en');
  });
}
