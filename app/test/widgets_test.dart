import 'package:devalay/core/favorites.dart';
import 'package:devalay/core/providers.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/japa.dart';
import 'package:devalay/features/rashifal.dart';
import 'package:devalay/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _app(Widget child, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

Map _reading(String slug, String name, int rating) => {
  'rashi': slug,
  'name': name,
  'name_en': name,
  'name_hi': name,
  'symbol': '♈',
  'rating': rating,
  'moon_rashi': 'simha',
  'moon_house': 5,
  'overview': 'A good day for $name',
  'love': 'l',
  'career': 'c',
  'health': 'h',
  'remedy': 'r',
  'lucky_color': 'Red',
  'lucky_number': 3,
  'disclaimer': 'd',
};

void main() {
  setUpAll(initTestStorage);

  // Real disk IO (Hive) must happen outside the fake-async test zone.
  setUp(() async {
    await Boxes.prefs.put('rashi', 'tula');
    await Boxes.prefs.put('language', 'en');
    await Boxes.favorites.clear();
  });

  testWidgets('Rashifal grid pins the user\'s rashi first and opens details', (tester) async {
    await tester.pumpWidget(
      _app(
        const RashifalScreen(),
        overrides: [
          rashifalProvider.overrideWith((ref) async => [_reading('mesha', 'Mesha', 3), _reading('tula', 'Tula', 5)]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your rashi'), findsOneWidget);
    final tula = tester.getTopLeft(find.text('Tula').first);
    final mesha = tester.getTopLeft(find.text('Mesha').first);
    expect(tula.dx < mesha.dx || tula.dy < mesha.dy, isTrue);
    await tester.tap(find.text('Tula').first);
    await tester.pumpAndSettle();
    expect(find.text('A good day for Tula'), findsOneWidget);
  });

  test('Favourites store toggles and persists on device', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final item = FavoriteItem(type: 'verse', id: '2.47', title: 'Gita 2.47');
    final notifier = container.read(favoritesProvider.notifier);
    await notifier.toggle(item);
    expect(container.read(favoritesProvider).containsKey('verse:2.47'), isTrue);
    expect(Boxes.favorites.containsKey('verse:2.47'), isTrue);
    await notifier.toggle(item);
    expect(container.read(favoritesProvider), isEmpty);
    expect(Boxes.favorites.containsKey('verse:2.47'), isFalse);
  });

  testWidgets('Favourite button reflects saved state', (tester) async {
    final item = FavoriteItem(type: 'text', id: 'hanuman-chalisa', title: 'Hanuman Chalisa');
    await tester.runAsync(() => Boxes.favorites.put(item.key, item.toJson()));
    await tester.pumpWidget(_app(Scaffold(body: FavoriteButton(item: item))));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('Error view offers a retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ErrorRetry(error: Exception('boom'), onRetry: () => retried = true),
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    expect(retried, isTrue);
  });

  // Last: its fire-and-forget Hive writes stay pending in the fake-async zone.
  testWidgets('Japa counter counts taps and stores them on device', (tester) async {
    await tester.pumpWidget(_app(const JapaScreen()));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(tester.getCenter(find.byType(JapaScreen)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('5'), findsWidgets);
    expect(Boxes.stats.get('japa_count'), 5);
    expect(Boxes.stats.get('japa_total'), 5);
  });
}
