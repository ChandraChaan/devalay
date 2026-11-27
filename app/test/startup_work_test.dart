import 'package:devalay/core/api.dart';
import 'package:devalay/core/json_asset.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/providers.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/core/thoughts.dart';
import 'package:devalay/features/mandir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestStorage);

  group('http cache', () {
    setUp(() => Boxes.cache.clear());

    test('drops single-day answers older than a week and keeps the rest', () async {
      const oldHome = '/home/city-hyderabad~day-2026-11-10.json?{}';
      const weekOld = '/rashifal/day-2026-11-20~lang-en.json?{}';
      const recent = '/home/city-hyderabad~day-2026-11-25.json?{}';
      const tomorrow = '/panchang/city-hyderabad~day-2026-11-28.json?{}';
      const month = '/panchang/month/city-hyderabad~month-11~year-2026.json?{}';
      const festivals = '/festivals/city-hyderabad~include_recurring-true~year-2025.json?{}';
      const serverStyle = '/panchang?{"lat":17.38,"day":"2026-10-01"}';
      await Boxes.cache.putAll({
        for (final k in [oldHome, weekOld, recent, tomorrow, month, festivals, serverStyle]) k: '{}',
      });

      await pruneHttpCache(now: DateTime(2026, 11, 27, 23, 30));

      expect(Boxes.cache.keys.toSet(), {weekOld, recent, tomorrow, month, festivals});
    });

    test('an empty cache or one with nothing stale is left alone', () async {
      await pruneHttpCache(now: DateTime(2026, 11, 27));
      expect(Boxes.cache.isEmpty, isTrue);
      await Boxes.cache.put('/config/index.json?{}', '{}');
      await pruneHttpCache(now: DateTime(2026, 11, 27));
      expect(Boxes.cache.length, 1);
    });
  });

  group('bundled JSON', () {
    test('large files are parsed off the UI isolate and read the same', () async {
      final thoughts = Thoughts(await loadJsonAsset('assets/data/thoughts.json'));
      expect(thoughts.of('en', DateTime(2026, 11, 27)), isNotNull);
      for (final f in ['temples', 'holidays', 'wishes', 'pooja_guides']) {
        expect(await loadJsonAsset('assets/data/$f.json'), isNotEmpty, reason: f);
      }
    });
  });

  group('Mandir', () {
    Deity deity(int id, String slug) =>
        Deity({'id': id, 'slug': slug, 'name': slug, 'image_url': 'https://example.org/$slug.jpg', 'color': '#FF8800'});
    final deities = [deity(1, 'ganesha'), deity(2, 'shiva'), deity(3, 'krishna')];

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [deitiesProvider.overrideWith((ref) async => deities)],
          child: MaterialApp(theme: buildTheme(Brightness.dark), home: const MandirScreen()),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('opens on the ishta devata without jumping a detached page view', (tester) async {
      await tester.runAsync(() async {
        await Boxes.prefs.put('language', 'en');
        await Boxes.prefs.put('ishta', 'krishna');
      });
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('krishna'), findsWidgets);
      await tester.pumpWidget(const SizedBox()); // dispose the screen and its animations
    });

    testWidgets('opens on the first shrine when no ishta devata is set', (tester) async {
      await tester.runAsync(() => Boxes.prefs.delete('ishta'));
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('ganesha'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
