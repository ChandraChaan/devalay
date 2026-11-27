import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/billing.dart';
import 'package:devalay/core/languages.dart';
import 'package:devalay/core/perks.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/temples.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/japa.dart';
import 'package:devalay/features/premium.dart';
import 'package:devalay/features/support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_fakes.dart';
import 'helpers.dart';

Future<ProviderContainer> _started(FakeStore store, [MemoryCache? cache]) async {
  final c = ProviderContainer(overrides: [...billingOverrides(store, cache)]);
  c.read(billingProvider);
  await c.read(billingProvider.notifier).start();
  return c;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

Future<void> _clearBilling() async {
  await Boxes.prefs.deleteAll([
    'premium',
    'premium_product',
    'premium_checked',
    'mandir_decor',
    'japa_mala',
    'japa_size',
  ]);
  await Boxes.stats.deleteAll(['support_prompt_at', 'support_gift_at', 'japa_count']);
}

void main() {
  setUpAll(initTestStorage);
  setUp(() async {
    await Boxes.prefs.put('language', 'en');
    await _clearBilling();
  });

  group('entitlement rules', () {
    final now = DateTime(2026, 11, 28, 10);

    test('Play\'s answer decides when Play can be asked', () {
      expect(premiumFrom(owned: {Products.premiumYearly}, cached: false, now: now), isTrue);
      expect(premiumFrom(owned: {Products.premiumMonthly, Products.support11}, cached: false, now: now), isTrue);
      expect(premiumFrom(owned: {Products.support101}, cached: true, checkedAt: now, now: now), isFalse);
      expect(premiumFrom(owned: {}, cached: true, checkedAt: now, now: now), isFalse);
    });

    test('the cached answer lasts 30 days while Play is unreachable', () {
      expect(
        premiumFrom(owned: null, cached: true, checkedAt: now.subtract(const Duration(days: 29)), now: now),
        isTrue,
      );
      expect(
        premiumFrom(owned: null, cached: true, checkedAt: now.subtract(const Duration(days: 31)), now: now),
        isFalse,
      );
      expect(premiumFrom(owned: null, cached: false, checkedAt: now, now: now), isFalse);
      expect(premiumFrom(owned: null, cached: true, now: now), isFalse);
      // A clock moved far back does not extend Premium for ever.
      expect(premiumFrom(owned: null, cached: true, checkedAt: now.add(const Duration(days: 40)), now: now), isFalse);
    });

    test('Premium choices fall back to the free look without Premium', () {
      expect(
        unlocked(MandirDecor.swarna, isPremiumItem: true, premium: false, free: MandirDecor.classic),
        MandirDecor.classic,
      );
      expect(
        unlocked(MandirDecor.swarna, isPremiumItem: true, premium: true, free: MandirDecor.classic),
        MandirDecor.swarna,
      );
      expect(
        unlocked(Accent.tulsi, isPremiumItem: Accent.tulsi.premium, premium: false, free: Accent.saffron),
        Accent.tulsi,
      );
      expect(Accent.values.where((a) => a.premium).length, 3);
      expect(MandirDecor.values.where((d) => !d.premium), [MandirDecor.classic]);
      expect(MalaStyle.values.where((m) => !m.premium), [MalaStyle.rudraksha]);
    });

    test('stored choices survive bad values', () async {
      expect(MandirDecor.byName('nope'), MandirDecor.classic);
      expect(MandirDecor.byName(null), MandirDecor.classic);
      expect(MalaStyle.byName(42), MalaStyle.rudraksha);
      await Boxes.prefs.put('japa_size', 13);
      expect(Perks.malaSize, 108);
      await Boxes.prefs.put('japa_size', '27');
      expect(Perks.malaSize, 108);
      await Perks.setMalaSize(27);
      expect(Perks.malaSize, 27);
      expect(malaSizePremium(108), isFalse);
      expect(malaSizePremium(54), isTrue);
    });

    test('product ids carry their rupee amounts', () {
      expect(Products.support.map(Products.rupees), [11, 51, 101, 251]);
      expect(Products.dakshina.map(Products.rupees), [11, 51, 101]);
      expect(Products.rupees(Products.premiumYearly), 0);
      expect(Products.all.length, 6);
    });

    test('the support card shows after a week of darshan, rarely, never to Premium', () {
      bool due({int streak = 7, bool premium = false, DateTime? shown, DateTime? gift}) =>
          shouldShowSupportPrompt(streak: streak, premium: premium, now: now, lastShown: shown, lastGift: gift);
      expect(due(), isTrue);
      expect(due(streak: 30), isTrue);
      expect(due(streak: 6), isFalse);
      expect(due(premium: true), isFalse);
      expect(due(shown: now.subtract(const Duration(days: 59))), isFalse);
      expect(due(shown: now.subtract(const Duration(days: 61))), isTrue);
      expect(due(gift: now.subtract(const Duration(days: 100))), isFalse);
      expect(due(gift: now.subtract(const Duration(days: 200))), isTrue);
    });
  });

  group('billing controller', () {
    test('an active subscription turns Premium on, is acknowledged and cached', () async {
      final store = FakeStore(owned: [purchase(Products.premiumYearly, PurchaseStatus.purchased)]);
      final cache = MemoryCache();
      final c = await _started(store, cache);
      addTearDown(c.dispose);
      final s = c.read(billingProvider);
      expect(s.ready, isTrue);
      expect(s.premium, isTrue);
      expect(c.read(premiumProvider), isTrue);
      expect(s.premiumProduct, Products.premiumYearly);
      expect(store.completed, [Products.premiumYearly]);
      expect(cache.premium, isTrue);
      expect(cache.product, Products.premiumYearly);
      expect(s.premiumPlans().map((p) => p.id), [Products.premiumYearly, Products.premiumMonthly]);
    });

    test('an acknowledged subscription is not acknowledged again', () async {
      final store = FakeStore(owned: [purchase(Products.premiumMonthly, PurchaseStatus.purchased, acknowledged: true)]);
      final c = await _started(store);
      addTearDown(c.dispose);
      expect(c.read(billingProvider).premium, isTrue);
      expect(store.completed, isEmpty);
    });

    test('a lapsed subscription turns Premium off', () async {
      final cache = cachedPremium();
      final store = FakeStore(owned: []);
      final c = ProviderContainer(overrides: [...billingOverrides(store, cache)]);
      addTearDown(c.dispose);
      expect(c.read(billingProvider).premium, isTrue, reason: 'cached until Play answers');
      await c.read(billingProvider.notifier).start();
      expect(c.read(billingProvider).premium, isFalse);
      expect(cache.premium, isFalse);
    });

    test('a tip left unconsumed is consumed and is not Premium', () async {
      final store = FakeStore(owned: [purchase(Products.support51, PurchaseStatus.purchased)]);
      final c = await _started(store);
      addTearDown(c.dispose);
      expect(store.consumed, [Products.support51]);
      expect(store.completed, isEmpty);
      expect(c.read(billingProvider).premium, isFalse);
    });

    test('without Play, the cached Premium stays and screens stop waiting', () async {
      final store = FakeStore(available: false);
      final c = await _started(store, cachedPremium());
      addTearDown(c.dispose);
      final s = c.read(billingProvider);
      expect(s.ready, isTrue);
      expect(s.available, isFalse);
      expect(s.premium, isTrue);
    });

    test('when Play cannot list purchases, the cached answer is kept', () async {
      final store = FakeStore(owned: null);
      final c = await _started(store, cachedPremium());
      addTearDown(c.dispose);
      expect(c.read(billingProvider).premium, isTrue);
    });

    test('a tip bought now is consumed, thanked and remembered', () async {
      final store = FakeStore();
      final cache = MemoryCache();
      final c = await _started(store, cache);
      addTearDown(c.dispose);
      final notifier = c.read(billingProvider.notifier);
      await notifier.buy(c.read(billingProvider).products[Products.support101]!, source: 'mandir');
      expect(store.bought, [(Products.support101, true)]);
      expect(c.read(billingProvider).busy, isTrue);
      store.stream.add([purchase(Products.support101, PurchaseStatus.purchased)]);
      await _settle();
      final s = c.read(billingProvider);
      expect(s.notice, BillingNotice.thanksSupport);
      expect(s.busy, isFalse);
      expect(store.consumed, [Products.support101]);
      expect(store.completed, isEmpty);
      expect(cache.giftAt, isNotNull);
      expect(s.premium, isFalse);
    });

    test('a subscription bought now turns Premium on and is acknowledged', () async {
      final store = FakeStore();
      final c = await _started(store);
      addTearDown(c.dispose);
      await c
          .read(billingProvider.notifier)
          .buy(c.read(billingProvider).products[Products.premiumYearly]!, source: 'premium');
      expect(store.bought, [(Products.premiumYearly, false)]);
      store.stream.add([purchase(Products.premiumYearly, PurchaseStatus.purchased)]);
      await _settle();
      final s = c.read(billingProvider);
      expect(s.premium, isTrue);
      expect(s.notice, BillingNotice.thanksPremium);
      expect(store.completed, [Products.premiumYearly]);
    });

    test('pending, cancelled and failed purchases each end the busy state once', () async {
      final store = FakeStore();
      final c = await _started(store);
      addTearDown(c.dispose);
      final notifier = c.read(billingProvider.notifier);
      final product = c.read(billingProvider).products[Products.support11]!;

      await notifier.buy(product, source: 'more');
      store.stream.add([purchase(Products.support11, PurchaseStatus.pending)]);
      await _settle();
      expect(c.read(billingProvider).notice, BillingNotice.pending);
      expect(c.read(billingProvider).busy, isFalse);

      final before = c.read(billingProvider).noticeId;
      await notifier.buy(product, source: 'more');
      store.stream.add([purchase(Products.support11, PurchaseStatus.canceled)]);
      await _settle();
      expect(c.read(billingProvider).busy, isFalse);
      expect(c.read(billingProvider).noticeId, before, reason: 'cancelling needs no message');

      await notifier.buy(product, source: 'more');
      store.stream.add([purchase(Products.support11, PurchaseStatus.error)]);
      await _settle();
      expect(c.read(billingProvider).notice, BillingNotice.failed);
      expect(c.read(billingProvider).noticeId, before + 1);
      expect(store.consumed, isEmpty);
    });

    test('restore reports what Play found', () async {
      final store = FakeStore(owned: []);
      final c = await _started(store);
      addTearDown(c.dispose);
      await c.read(billingProvider.notifier).restore();
      expect(c.read(billingProvider).notice, BillingNotice.nothingToRestore);
      store.owned = [purchase(Products.premiumMonthly, PurchaseStatus.purchased, acknowledged: true)];
      await c.read(billingProvider.notifier).restore();
      expect(c.read(billingProvider).notice, BillingNotice.restored);
      expect(c.read(billingProvider).premium, isTrue);
    });

    test('products not yet in Play Console are simply missing', () async {
      final store = FakeStore(products: []);
      final c = await _started(store);
      addTearDown(c.dispose);
      expect(c.read(billingProvider).premiumPlans(), isEmpty);
      expect(c.read(billingProvider).supportProducts(Products.support), isEmpty);
    });
  });

  group('screens', () {
    final catalog = TempleCatalog(jsonDecode(File('assets/data/temples.json').readAsStringSync()) as Map);

    Widget app(Widget home, FakeStore store, {MemoryCache? cache, Brightness brightness = Brightness.light}) =>
        ProviderScope(
          overrides: [
            ...billingOverrides(store, cache),
            templeCatalogProvider.overrideWith((ref) => Stream.value(catalog)),
          ],
          child: MaterialApp(theme: buildTheme(brightness), home: home),
        );

    // A tall phone, so whole screens fit without scrolling.
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    // Hive writes started by the screens do real file IO: give it real time to finish, or a write
    // left half-done in the fake-async zone would block the box for the next test.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      }
    }

    // Ends a test with the tree gone and every pending write finished.
    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    }

    testWidgets('Premium shows Play prices, the perks and buys the yearly plan', (tester) async {
      tall(tester);
      final store = FakeStore();
      await tester.pumpWidget(app(const PremiumScreen(source: 'test'), store));
      await settle(tester);
      expect(find.text('₹299'), findsOneWidget);
      expect(find.text('₹49'), findsOneWidget);
      expect(find.text('Best value: about ₹25 a month'), findsOneWidget);
      expect(find.text('No ads, now or ever'), findsOneWidget);
      await tester.tap(find.text('₹299'));
      await tester.pump();
      expect(store.bought, [(Products.premiumYearly, false)]);
      store.stream.add([purchase(Products.premiumYearly, PurchaseStatus.purchased)]);
      await settle(tester);
      expect(find.text('You are Premium'), findsOneWidget);
      expect(find.text('Manage subscription'), findsOneWidget);
      expect(find.text('₹299'), findsNothing);
      expect(tester.takeException(), isNull);
      await done(tester);
    });

    testWidgets('Premium says so plainly when Play has no products yet', (tester) async {
      tall(tester);
      await tester.pumpWidget(app(const PremiumScreen(), FakeStore(products: [])));
      await settle(tester);
      expect(find.text('Premium is coming soon on Google Play.'), findsOneWidget);
    });

    testWidgets('Premium says so plainly when Play billing is missing', (tester) async {
      tall(tester);
      await tester.pumpWidget(app(const PremiumScreen(), FakeStore(available: false)));
      await settle(tester);
      expect(find.text('Google Play payments are not available on this phone.'), findsOneWidget);
    });

    testWidgets('Support Devalay offers four amounts, says who gets the money and lists temples', (tester) async {
      final store = FakeStore();
      await tester.pumpWidget(app(const SupportScreen(), store));
      await settle(tester);
      for (final p in ['₹11', '₹51', '₹101', '₹251']) {
        expect(find.text(p), findsOneWidget);
      }
      expect(find.textContaining('not a donation to any temple'), findsOneWidget);
      await tester.tap(find.text('₹51'));
      await tester.pump();
      expect(store.bought, [(Products.support51, true)]);
      store.stream.add([purchase(Products.support51, PurchaseStatus.purchased)]);
      await settle(tester);
      expect(find.text('Thank you'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('TTD · Tirumala · e-Hundi'), 300);
      expect(find.text('Bhadrachalam · Donation and e-Hundi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await done(tester);
    });

    testWidgets('Dakshina keeps temple giving and Devalay dakshina apart', (tester) async {
      final store = FakeStore();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(onPressed: () => showDakshinaSheet(context), child: const Text('open')),
            ),
          ),
          store,
        ),
      );
      await settle(tester);
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text('Offer dakshina'), findsOneWidget);
      expect(find.text('At a temple'), findsOneWidget);
      expect(find.text('TTD · Tirumala · e-Hundi'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('₹101'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('₹11'), findsOneWidget);
      expect(find.text('₹251'), findsNothing, reason: 'dakshina offers 11, 51 and 101');
      await tester.tap(find.text('₹101'));
      await tester.pump();
      expect(store.bought, [(Products.support101, true)]);
      expect(tester.takeException(), isNull);
      await done(tester);
    });

    testWidgets('every screen renders in all 11 languages without overflow', (tester) async {
      for (final l in appLanguages) {
        await tester.runAsync(() => Boxes.prefs.put('language', l.code));
        for (final screen in [const PremiumScreen(), const SupportScreen()]) {
          await tester.pumpWidget(app(screen, FakeStore()));
          await settle(tester);
          expect(tester.takeException(), isNull, reason: '${screen.runtimeType} in ${l.code}');
        }
      }
      await tester.runAsync(() => Boxes.prefs.put('language', 'en'));
    });

    testWidgets('Japa uses the chosen mala and round with Premium, the free ones without', (tester) async {
      await tester.runAsync(() async {
        await Perks.setMalaSize(27);
        await Perks.setMala(MalaStyle.sphatik);
      });
      await tester.pumpWidget(app(const Scaffold(body: JapaScreen()), FakeStore(owned: [])));
      await settle(tester);
      expect(find.text('/ 108'), findsOneWidget, reason: 'no Premium: full mala');

      final premiumStore = FakeStore(owned: [purchase(Products.premiumYearly, PurchaseStatus.purchased)]);
      await done(tester);
      await tester.pumpWidget(app(const Scaffold(body: JapaScreen()), premiumStore, cache: cachedPremium()));
      await settle(tester);
      expect(find.text('/ 27'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.blur_circular_rounded));
      await settle(tester);
      await tester.tap(find.text('108'));
      await settle(tester);
      expect(find.text('/ 108'), findsOneWidget);
      expect(Perks.malaSize, 108);
      expect(tester.takeException(), isNull);
      await done(tester);
    });
  });
}
