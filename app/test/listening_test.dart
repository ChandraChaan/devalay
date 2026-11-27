import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/audio.dart';
import 'package:devalay/core/listening.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/providers.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/telugu.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/listen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Track _track(int id, String slug, String kind, {int dur = 60, String title = ''}) => Track({
  'id': id,
  'slug': slug,
  'title': title.isEmpty ? slug : title,
  'title_hi': '',
  'kind': kind,
  'audio_url': 'https://example.org/$slug.mp3',
  'artwork_url': '',
  'duration_sec': dur,
});

final _catalogue = [
  _track(1, 'gayatri-mantra-chant', 'mantra', dur: 21, title: 'Gayatri Mantra'),
  _track(3, 'mahamrityunjaya-chant', 'mantra', dur: 18),
  _track(5, 'aarti-ganpati-vandana', 'aarti', dur: 76, title: 'Ganpati Vandana Aarti'),
  _track(28, 'siva-panchakshara-mss', 'mantra', dur: 2313),
  _track(21, 'brihat-sama', 'mantra', dur: 104),
  _track(23, 'annamacharya-brahma-kadigina-paadamu', 'bhajan', dur: 280, title: 'Brahma Kadigina Paadamu'),
  _track(47, 'ringtone-shankh-naad', 'ringtone', dur: 20, title: 'Shankh Naad'),
];

void main() {
  setUpAll(initTestStorage);

  group('popular list', () {
    test('Remote Config ids are read in order; junk falls back to the default list', () {
      expect(parseTrackIds('5, 1,3'), [5, 1, 3]);
      expect(parseTrackIds('7,x,-2,0,9'), [7, 9]);
      expect(parseTrackIds(''), defaultPopularTrackIds);
      expect(parseTrackIds('none'), defaultPopularTrackIds);
    });

    test('tracksByIds keeps the given order and skips ids the catalogue lacks', () {
      expect(tracksByIds(_catalogue, [5, 999, 1]).map((t) => t.id), [5, 1]);
    });

    test('default list names real tracks, ringtones left out', () {
      expect(defaultPopularTrackIds.toSet().length, defaultPopularTrackIds.length);
      expect(defaultPopularTrackIds.any((id) => id >= 46), isFalse); // 46–50 are ringtones
    });
  });

  test('Telugu keerthanalu are real catalogue slugs, listed once, each with a Telugu title', () {
    List<String> slugsIn(String path, String key) => [
      for (final t in (jsonDecode(File(path).readAsStringSync()) as Map)[key] as List) (t as Map)['slug'] as String,
    ];
    final catalogue = {
      ...slugsIn('../backend/app/seed/data/commons.json', 'tracks'),
      ...slugsIn('../backend/app/seed/data/telugu_audio.json', 'tracks'),
    };
    expect(teluguKeerthanaSlugs.toSet(), hasLength(teluguKeerthanaSlugs.length));
    for (final s in teluguKeerthanaSlugs) {
      expect(catalogue, contains(s));
      expect(teluguTrackTitles, contains(s));
    }
    // Every single song cut from the Telugu/Carnatic albums gets a Telugu title too.
    for (final s in slugsIn('../backend/app/seed/data/telugu_audio.json', 'tracks')) {
      expect(teluguTrackTitles, contains(s));
    }
    expect(teluguTrackTitles.keys.where((s) => !catalogue.contains(s)), isEmpty);
  });

  test('only short mantra clips can be chanted', () {
    expect(_catalogue.where(isChantable).map((t) => t.id), [1, 3]);
  });

  test('recently played: newest first, no duplicates, no ringtones, capped, saved', () async {
    await Boxes.prefs.delete('recent_tracks');
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final recent = c.read(recentTrackIdsProvider.notifier);
    Track byId(int id) => _catalogue.firstWhere((t) => t.id == id);
    recent.add(byId(1));
    recent.add(byId(5));
    recent.add(byId(1));
    recent.add(_catalogue.firstWhere((t) => t.kind == 'ringtone')); // ringtone preview: not "listening"
    expect(c.read(recentTrackIdsProvider), [1, 5]);
    for (var i = 100; i < 120; i++) {
      recent.add(_track(i, 's$i', 'bhajan'));
    }
    expect(c.read(recentTrackIdsProvider).length, RecentTracks.max);
    expect(c.read(recentTrackIdsProvider).first, 119);
    expect(Boxes.prefs.get('recent_tracks'), c.read(recentTrackIdsProvider));
  });

  test('chant progress counts to the target', () {
    final p = ChantProgress(track: _catalogue[0], target: 11, done: 10);
    expect(p.finished, isFalse);
    expect(p.copyWith(done: 11).finished, isTrue);
    expect(p.copyWith(done: 11).track.id, 1);
  });

  group('Listen page', () {
    Future<void> open(WidgetTester tester, String lang, {List<int> recent = const []}) async {
      // A typical phone: 360 x 800 dp.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await Boxes.prefs.put('language', lang);
        await Boxes.prefs.put('recent_tracks', recent);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksProvider.overrideWith((ref, q) async {
              if (q.deity != null) return const <Track>[];
              if (q.kind == 'ringtone') return _catalogue.where((t) => t.kind == 'ringtone').toList();
              return _catalogue;
            }),
            deitiesProvider.overrideWith((ref) async => const <Deity>[]),
            currentTrackProvider.overrideWith((ref) => Stream.value(null)),
            playingProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: MaterialApp(theme: buildTheme(Brightness.light), home: const ListenScreen()),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('shows type tiles, chanting and the most played row', (tester) async {
      await open(tester, 'en');
      expect(tester.takeException(), isNull);
      expect(find.text('Chant with the mantra'), findsOneWidget);
      expect(find.text('Most played'), findsOneWidget);
      expect(find.text('Gayatri Mantra'), findsWidgets);
      expect(find.text('Continue listening'), findsNothing); // nothing played yet
    });

    testWidgets('Telugu users get Telugu labels and the keerthanalu row', (tester) async {
      await open(tester, 'te', recent: const [5]);
      expect(tester.takeException(), isNull);
      expect(find.text('వినడం కొనసాగించండి'), findsOneWidget);
      expect(find.text('ఎక్కువ మంది వింటున్నవి'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('తెలుగు కీర్తనలు'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('తెలుగు కీర్తనలు'), findsOneWidget);
      expect(find.text('బ్రహ్మ కడిగిన పాదము – అన్నమాచార్య'), findsOneWidget);
    });
  });
}
