import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/billing.dart';
import 'package:devalay/core/sections.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/meditation.dart';
import 'package:devalay/features/ringtones.dart';
import 'package:devalay/features/wallpaper_gallery.dart';
import 'package:devalay/widgets/premium_lock.dart';
import 'package:devalay/widgets/status_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_fakes.dart';
import 'helpers.dart';

/// The sections catalogue (assets/data/sections.json) and its Premium rules: the five best items of each
/// section are Premium, everything else is free, and only Premium unlocks them.
void main() {
  final json = jsonDecode(File('assets/data/sections.json').readAsStringSync()) as Map;
  final catalog = SectionsCatalog(json);
  const allowed = {
    'Public domain',
    'CC0',
    'CC BY 2.0',
    'CC BY 3.0',
    'CC BY 4.0',
    'CC BY-SA 2.0',
    'CC BY-SA 3.0',
    'CC BY-SA 4.0',
    'FAL',
  };

  void topFive(String name, List<SectionItem> items) {
    test('$name: exactly the top five are Premium, ranked 1 to 5 and listed first', () {
      expect(items, isNotEmpty);
      final premium = items.where((i) => i.isPremium).toList();
      expect(premium.map((i) => i.premiumRank), [1, 2, 3, 4, 5]);
      expect(items.take(5).every((i) => i.isPremium), isTrue);
      expect(items.skip(5).every((i) => !i.isPremium), isTrue);
      expect(items.map((i) => i.id).toSet().length, items.length, reason: 'ids are unique');
    });
  }

  topFive('wallpapers', catalog.wallpapers);
  topFive('ringtones', catalog.ringtones);
  topFive('status videos', catalog.statusVideos);
  if (catalog.meditation.isNotEmpty) topFive('meditation', catalog.meditation);

  test('the catalogue is a supported schema with a version', () {
    expect(catalog.schema, SectionsCatalog.supportedSchema);
    expect(catalog.version, greaterThan(0));
  });

  test('every item is licensed for reuse and credited, with https media', () {
    final credits = [
      for (final w in catalog.wallpapers) w.credit,
      for (final r in catalog.ringtones) r.credit,
      for (final v in catalog.statusVideos) ...[v.artCredit, v.audioCredit],
      for (final m in catalog.meditation) m.credit,
    ];
    for (final c in credits) {
      expect(allowed, contains(c.license), reason: c.line);
      expect(c.author, isNotEmpty);
      expect(c.source, startsWith('https://'));
    }
    for (final w in catalog.wallpapers) {
      for (final url in [w.thumb, w.fhd, w.qhd]) {
        expect(url, startsWith('https://'));
      }
      expect({'modern', 'photo', 'classic'}, contains(w.style));
    }
    for (final r in catalog.ringtones) {
      expect(r.audio, startsWith('https://'));
      expect(r.notification, startsWith('https://'));
      expect(r.seconds, inInclusiveRange(1, 31));
    }
    for (final v in catalog.statusVideos) {
      expect(v.video, endsWith('.mp4'));
      expect(v.seconds, lessThanOrEqualTo(30), reason: 'WhatsApp status length');
    }
  });

  test('Premium entitlement: locked without Premium, open with it, free items never locked', () {
    final premiumItem = catalog.wallpapers.first;
    final freeItem = catalog.wallpapers.last;
    expect(isLocked(premiumItem, premium: false), isTrue);
    expect(isLocked(premiumItem, premium: true), isFalse);
    expect(isLocked(freeItem, premium: false), isFalse);
    expect(isLocked(freeItem, premium: true), isFalse);
  });

  test('premiumFirst orders by rank, then keeps the free order', () {
    SectionItem item(String id, int? rank) => Ringtone({'id': id, 'premium': rank});
    final sorted = premiumFirst([item('a', null), item('b', 3), item('c', 1), item('d', null), item('e', 2)]);
    expect(sorted.map((i) => i.id), ['c', 'e', 'b', 'a', 'd']);
  });

  test('Today matches festivals before the weekday', () {
    final monday = DateTime(2026, 11, 30, 9);
    final tags = todayTags(monday, festivals: ['karthika']);
    expect(tags, containsAll(['monday', 'morning', 'karthika']));
    final today = forToday(catalog.statusVideos, tags);
    expect(today, isNotEmpty);
    expect(today.first.tags, contains('karthika'));
  });

  test('the Premium source names the item that was tapped', () {
    expect(parsePremiumSource('wallpaper:lakshmi-1930'), ('wallpaper', 'lakshmi-1930'));
    expect(parsePremiumSource('status_template:swarna'), ('status_template', 'swarna'));
    expect(parsePremiumSource('mandir'), isNull);
    expect(parsePremiumSource('unknown:x'), isNull);
    expect(itemRef(catalog.ringtones.first), startsWith('ringtone:'));
  });

  test('downloaded files keep the release file name', () {
    expect(
      SectionFiles.fileNameFor('https://github.com/x/releases/download/media-sections-v1/wp-om-glow-qhd.jpg'),
      'wp-om-glow-qhd.jpg',
    );
  });

  test('AI Status has twelve or more designs, the first five Premium', () {
    final premium = StatusTemplate.values.where((t) => t.isPremium).toList();
    expect(premium.map((t) => t.premiumRank), [1, 2, 3, 4, 5]);
    expect(StatusTemplate.values.length, greaterThanOrEqualTo(12));
  });

  test('breathing follows the pattern', () {
    const calm = [4, 4, 6, 0];
    expect(breathPhase(calm, 1).phase, 0);
    expect(breathPhase(calm, 5).phase, 1);
    expect(breathPhase(calm, 9).phase, 2);
    expect(breathPhase(calm, 14.5).phase, 0, reason: 'the next cycle');
    expect(breathPhase(const [], 3).phase, -1);
  });

  group('screens', () {
    setUpAll(() async {
      await initTestStorage();
      await Boxes.prefs.put('language', 'en');
    });

    Future<void> open(WidgetTester tester, Widget screen, {required bool premium}) async {
      final store = FakeStore(owned: premium ? [purchase(Products.premiumYearly, PurchaseStatus.purchased)] : []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...billingOverrides(store, premium ? cachedPremium() : null),
            sectionsProvider.overrideWith((ref) => Stream.value(catalog)),
          ],
          child: MaterialApp(theme: buildTheme(Brightness.light), home: screen),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('ringtones: locked Premium tones show a lock, Premium members get Set', (tester) async {
      await open(tester, const RingtonesScreen(), premium: false);
      expect(tester.takeException(), isNull);
      expect(find.text('Premium collection'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
      await tester.pumpWidget(const SizedBox());

      await open(tester, const RingtonesScreen(), premium: true);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('wallpapers: a locked wallpaper opens a watermarked preview with Unlock', (tester) async {
      await open(tester, const WallpaperGalleryScreen(), premium: false);
      expect(tester.takeException(), isNull);
      final first = catalog.wallpapers.first;
      await tester.tap(find.text(first.title.en).first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byType(PremiumWatermark), findsWidgets);
      expect(find.byType(UnlockButton), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await open(tester, const WallpaperGalleryScreen(), premium: true);
      await tester.tap(find.text(first.title.en).first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byType(UnlockButton), findsNothing);
      expect(find.text('Set wallpaper'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
