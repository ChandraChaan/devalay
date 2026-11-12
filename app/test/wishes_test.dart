import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:devalay/core/api.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/core/wishes.dart';
import 'package:devalay/features/wishes.dart';
import 'package:devalay/widgets/wish_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map _json() => jsonDecode(File('assets/data/wishes.json').readAsStringSync()) as Map;
WishCatalog _bundled() => WishCatalog(_json());

Festival _festival(String slug, String date) =>
    Festival({'slug': slug, 'kind': 'festival', 'name': slug, 'name_hi': '', 'deity': '', 'date': date});

/// The calendar around Diwali 2026, as the API would send it.
final _calendar = [
  _festival('sharad-navratri', '2026-10-11'),
  _festival('dussehra', '2026-10-20'),
  _festival('diwali', '2026-11-08'),
  _festival('kartik-purnima', '2026-11-24'),
  _festival('gita-jayanti', '2026-12-20'),
  _festival('bhogi', '2027-01-13'),
  _festival('makar-sankranti', '2027-01-14'),
];

class _FakeApi extends Api {
  _FakeApi(this.data);
  final Object? data;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool cache = true}) async {
    if (data == null) throw ApiException('offline');
    return data;
  }
}

Widget _app(Widget child, {DateTime? now, WishPhotoPicker? picker}) => ProviderScope(
  overrides: [
    wishCatalogProvider.overrideWith((ref) => Stream.value(_bundled())),
    wishClockProvider.overrideWithValue(() => now ?? DateTime(2026, 11, 12, 8)),
    wishCalendarProvider.overrideWithValue(_calendar),
    wishPaintingsProvider.overrideWith((ref, deity) async => const <Wallpaper>[]),
    if (picker != null) wishPhotoPickerProvider.overrideWithValue(picker),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

/// A small PNG standing in for the user's photo.
Future<File> _photoFile(WidgetTester tester) async {
  late File file;
  // Real file work has to run outside the test's fake clock.
  await tester.runAsync(() async {
    file = File('${(await Directory.systemTemp.createTemp('wish-photo')).path}/me.png');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 60), Paint()..color = const Color(0xFF8D6E63));
    final image = await recorder.endRecording().toImage(40, 60);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
  return file;
}

/// Closes the screen, which saves the name on the way out.
Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestStorage);
  setUp(() async {
    await Boxes.prefs.put('language', 'en');
    WishProfile.memory = {};
  });

  group('bundled catalogue', () {
    final catalog = _bundled();
    final raw = _json();

    test('has the schema this app reads, and every set and theme in it is usable', () {
      expect(catalog.schema, WishCatalog.supportedSchema);
      expect(catalog.version, greaterThan(0));
      expect(catalog.updated, isNotNull);
      expect(catalog.festivals, hasLength((raw['festivals'] as List).length), reason: 'no set was dropped');
      final ids = catalog.festivals.map((f) => f.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final themeIds = [for (final f in catalog.festivals) ...f.themes.map((t) => t.id)];
      expect(themeIds.toSet(), hasLength(themeIds.length));
    });

    test('covers the major festivals with at least two themes each', () {
      for (final id in [
        'daily',
        'diwali',
        'navratri',
        'dussehra',
        'ganesh-chaturthi',
        'sankranti',
        'ugadi',
        'maha-shivratri',
        'holi',
        'ram-navami',
        'janmashtami',
        'raksha-bandhan',
      ]) {
        expect(catalog.byId(id)?.themes.length, greaterThanOrEqualTo(2), reason: id);
      }
      expect(catalog.daily?.id, 'daily');
    });

    test('every caption and wish is written in English, Hindi and Telugu', () {
      for (final f in catalog.festivals) {
        expect(f.name('hi'), isNot(f.name('en')), reason: f.id);
        expect(f.name('te'), isNot(f.name('en')), reason: f.id);
        expect(f.wishes.length, greaterThanOrEqualTo(3), reason: '${f.id} ready-made wishes');
        for (final t in [...f.captions, ...f.wishes]) {
          final en = t.text('en');
          expect(t.text('hi'), allOf(isNotEmpty, isNot(en)), reason: '${f.id}: $en');
          expect(t.text('te'), allOf(isNotEmpty, isNot(en)), reason: '${f.id}: $en');
        }
        for (final t in f.themes) {
          expect(t.name('te'), isNot(t.name('en')), reason: t.id);
        }
      }
    });

    test('themes name only layouts, decorations and colours this build draws', () {
      final layouts = WishLayout.values.map((l) => l.id).toSet();
      final hex = RegExp(r'^#[0-9A-Fa-f]{6}$');
      final usedLayouts = <String>{};
      for (final f in raw['festivals'] as List) {
        for (final t in (f as Map)['themes'] as List) {
          final theme = t as Map;
          expect(layouts, contains(theme['layout']), reason: '${theme['id']}');
          usedLayouts.add('${theme['layout']}');
          for (final c in [...theme['colors'] as List, theme['accent'], theme['ink']]) {
            expect(hex.hasMatch('$c'), isTrue, reason: '${theme['id']} colour $c');
          }
          if (theme['top'] != null) expect(WishMotifs.top, contains(theme['top']), reason: '${theme['id']}');
          if (theme['bottom'] != null) expect(WishMotifs.bottom, contains(theme['bottom']), reason: '${theme['id']}');
          if (theme['backdrop'] != null) {
            expect(WishMotifs.backdrop, contains(theme['backdrop']), reason: '${theme['id']}');
          }
        }
      }
      expect(WishLayout.values.length, greaterThanOrEqualTo(5));
      expect(usedLayouts, layouts, reason: 'every layout is some theme\'s default');
    });

    test('calendar matches are festival slugs the backend computes', () {
      final rules = File('../backend/app/services/festivals.py').readAsStringSync();
      final slugs = RegExp(r'FestivalRule\(\s*"([a-z-]+)"').allMatches(rules).map((m) => m[1]).toSet();
      expect(slugs, isNotEmpty);
      for (final f in catalog.festivals) {
        for (final m in f.match) {
          expect(slugs, contains(m), reason: '${f.id} matches $m');
        }
        // A festival follows the calendar or has a fixed date.
        if (f.kind == 'festival') {
          expect(f.match.isNotEmpty || f.nextDate(const [], DateTime(2026)) != null, isTrue, reason: f.id);
        }
      }
    });
  });

  group('dates', () {
    final catalog = _bundled();

    test('the next festival comes first and the daily set is left out', () {
      final list = upcomingWishes(catalog, _calendar, DateTime(2026, 11, 12, 8));
      expect(list.first.festival.id, 'kartik-purnima');
      expect(list.first.date, DateTime(2026, 11, 24));
      expect(list.map((w) => w.festival.id), isNot(contains('daily')));
      // New Year has a fixed date; birthdays have none and come last.
      final newYear = list.firstWhere((w) => w.festival.id == 'new-year');
      expect(newYear.date, DateTime(2027, 1, 1));
      expect(list.last.date, isNull);
      // Diwali has passed this year and the calendar does not know next year's yet.
      expect(list.firstWhere((w) => w.festival.id == 'diwali').date, isNull);
    });

    test('a festival of several days stays current until its last day', () {
      final navratri = catalog.byId('navratri')!;
      expect(navratri.nextDate(_calendar, DateTime(2026, 10, 15)), DateTime(2026, 10, 11));
      expect(navratri.nextDate(_calendar, DateTime(2026, 10, 19)), DateTime(2026, 10, 11));
      expect(navratri.nextDate(_calendar, DateTime(2026, 10, 20)), isNull);
      final first = upcomingWishes(catalog, _calendar, DateTime(2026, 10, 15)).first;
      expect(first.festival.id, 'navratri');
      expect(whenLabel(first.date, DateTime(2026, 10, 15), 'en'), 'On now');
      // Sankranti starts with Bhogi.
      expect(catalog.byId('sankranti')!.nextDate(_calendar, DateTime(2027, 1, 1)), DateTime(2027, 1, 13));
      expect(catalog.byId('sankranti')!.nextDate(_calendar, DateTime(2027, 1, 15)), DateTime(2027, 1, 13));
    });

    test('a calendar festival finds its wishes by slug', () {
      expect(catalog.forFestival(_festival('makar-sankranti', '2027-01-14'))?.id, 'sankranti');
      expect(catalog.forFestival(_festival('diwali', '2026-11-08'))?.id, 'diwali');
      expect(catalog.forFestival(_festival('pitru-paksha', '2026-09-27')), isNull);
    });

    test('the daily card greets by the hour and honours the deity of the weekday', () {
      final daily = catalog.daily!;
      final monday8 = DateTime(2026, 11, 16, 8);
      expect(daily.captionsFor(monday8).map((c) => c.text('en')).take(2), ['Good morning', 'Om Namah Shivaya']);
      expect(daily.captionsFor(DateTime(2026, 11, 16, 22)).first.text('te'), 'శుభ రాత్రి');
      expect(daily.captionsFor(DateTime(2026, 11, 17, 2)).first.text('en'), 'Good night');
      expect(daily.captionsFor(DateTime(2026, 11, 17, 17)).first.text('hi'), 'शुभ संध्या');
      expect(daily.deity(monday8), 'shiva');
      expect(daily.deity(DateTime(2026, 11, 21)), 'venkateswara');
      expect(daily.wishesFor(monday8).first.text('en'), contains('morning'));
      // The unconditional caption is always offered.
      expect(daily.captionsFor(monday8).map((c) => c.text('en')), contains('Have a blessed day'));
      expect(daily.captionsFor(monday8).map((c) => c.text('en')), isNot(contains('Jai Hanuman')));
    });

    test('labels and the year in a caption', () {
      final now = DateTime(2026, 11, 12, 20);
      expect(whenLabel(DateTime(2026, 11, 12), now, 'en'), 'Today');
      expect(whenLabel(DateTime(2026, 11, 13), now, 'hi'), 'कल');
      expect(whenLabel(DateTime(2026, 11, 24), now, 'en'), 'In 12 days · 24 Nov');
      expect(whenLabel(DateTime(2026, 11, 24), now, 'te'), '12 రోజుల్లో · 24 నవంబర్');
      expect(whenLabel(null, now, 'en'), '');
      expect(fillCaption('Happy New Year {year}', DateTime(2027, 1, 1), now), 'Happy New Year 2027');
    });
  });

  group('published catalogue', () {
    test('an unknown layout or decoration falls back; a set without themes is dropped', () {
      final json = _json();
      final first = (json['festivals'] as List).first as Map;
      ((first['themes'] as List).first as Map)
        ..['layout'] = 'hologram'
        ..['top'] = 'fireworks';
      (json['festivals'] as List).add({
        'id': 'broken',
        'name': {'en': 'Broken'},
        'captions': [
          {'en': 'Hi'},
        ],
        'themes': [],
      });
      final catalog = WishCatalog(json);
      expect(catalog.byId('broken'), isNull);
      expect(catalog.festivals.first.themes.first.layout, WishLayout.darshan);
      expect(catalog.festivals.first.themes.first.top, 'fireworks');
    });

    test('a newer published copy replaces the bundled one; an older or foreign one does not', () async {
      Future<int> versionWith(Object? remote) async {
        final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(_FakeApi(remote))]);
        addTearDown(container.dispose);
        final versions = <int>[];
        container.listen(wishCatalogProvider, (_, next) {
          if (next.value != null) versions.add(next.value!.version);
        }, fireImmediately: true);
        await container.read(wishCatalogProvider.future);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return versions.last;
      }

      final bundled = _bundled().version;
      expect(await versionWith({..._json(), 'version': bundled + 1}), bundled + 1);
      expect(await versionWith({..._json(), 'version': bundled}), bundled);
      expect(await versionWith({..._json(), 'version': bundled + 1, 'schema': 2}), bundled);
      expect(await versionWith({'schema': 1, 'version': bundled + 1, 'festivals': []}), bundled);
      expect(await versionWith(null), bundled);
    });
  });

  test('photo position stays inside its frame and survives a restart', () async {
    const view = PhotoView(scale: 2, x: 0.5, y: -0.5);
    expect(view.copyWith(scale: 9).scale, PhotoView.maxScale);
    expect(view.copyWith(scale: 0.2).scale, 1);
    expect(view.copyWith(x: -3).x, -1);
    expect(PhotoView.parse(view.toJson()).x, 0.5);
    expect(PhotoView.parse('junk').scale, PhotoView.initial.scale);
    await WishProfile.setView(view);
    expect(WishProfile.view.scale, 2);
  });

  testWidgets('every layout draws with and without a photo, and exports at 1080×1920', (tester) async {
    final photo = FileImage(await _photoFile(tester));
    final theme = _bundled().byId('diwali')!.themes.first;
    final key = GlobalKey();
    for (final layout in WishLayout.values) {
      for (final withPhoto in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 270,
                height: 480,
                child: RepaintBoundary(
                  key: key,
                  child: WishCard(
                    WishCardData(
                      theme: theme,
                      layout: layout,
                      caption: 'దీపావళి శుభాకాంక్షలు ఎంతో ఎంతో పొడవైన శీర్షిక',
                      message: 'May the light of the diyas fill your home with joy, health and prosperity.',
                      name: 'Suresh Kumar',
                      line2: '& family',
                      fromLabel: 'With best wishes',
                      photo: withPhoto ? photo : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '${layout.id} photo: $withPhoto');
        expect(find.text('Suresh Kumar'), findsOneWidget, reason: layout.id);
        expect(find.byType(Image), withPhoto ? findsOneWidget : findsNothing, reason: layout.id);
      }
    }
    await tester.runAsync(() async {
      final box = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await box.toImage(pixelRatio: 1080 / box.size.width);
      expect((image.width, image.height), (1080, 1920));
    });
  });

  testWidgets('wishes list puts the next festival first, then the daily card', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const WishesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('🌕 Kartik Purnima'), findsOneWidget);
    expect(find.text('In 12 days · 24 Nov'), findsOneWidget);
    expect(find.text('Good morning'), findsWidgets);
    expect(find.text('Make card'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Any day'), 300);
    expect(find.text('Birthday'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Your photo stays on this phone'), 300);
    expect(find.textContaining('Your photo stays on this phone'), findsOneWidget);
  });

  testWidgets('wishes list in Telugu', (tester) async {
    _phone(tester);
    await tester.runAsync(() => Boxes.prefs.put('language', 'te'));
    await tester.pumpWidget(_app(const WishesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('🌕 కార్తీక పౌర్ణమి'), findsOneWidget);
    expect(find.text('శుభోదయం'), findsWidgets);
  });

  testWidgets('editor: caption per language, own words kept, name remembered', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const WishEditorScreen(id: 'diwali')));
    await tester.pumpAndSettle();
    TextField field(String key) => tester.widget<TextField>(find.byKey(ValueKey(key)));
    String captionOnCard() => tester.widget<WishCard>(find.byType(WishCard).first).data.caption;

    await tester.tap(find.text('Words'));
    await tester.pumpAndSettle();
    expect(field('wish-caption').controller!.text, 'Happy Diwali');
    expect(captionOnCard(), 'Happy Diwali');

    await tester.tap(find.text('తెలుగు'));
    await tester.pumpAndSettle();
    expect(field('wish-caption').controller!.text, 'దీపావళి శుభాకాంక్షలు');
    expect(tester.widget<WishCard>(find.byType(WishCard).first).data.message, startsWith('దీపాల వెలుగు'));

    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();
    expect(captionOnCard(), 'दीपावली की शुभकामनाएँ');

    final list = find.byKey(const ValueKey('wish-words-list'));
    final scroller = find.descendant(of: list, matching: find.byType(Scrollable)).first;
    // Scrolls by position: a drag could land on the multi-line message field and scroll that instead.
    Future<void> reveal(Finder target) async {
      final position = tester.state<ScrollableState>(scroller).position;
      for (var y = 0.0; target.evaluate().isEmpty && y <= position.maxScrollExtent + 100; y += 100) {
        position.jumpTo(y.clamp(0, position.maxScrollExtent));
        await tester.pump();
      }
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
    }

    Future<void> type(String key, String text) async {
      await reveal(find.byKey(ValueKey(key)));
      await tester.enterText(find.byKey(ValueKey(key)), text);
      await tester.pump();
    }

    await type('wish-caption', 'Shubh Deepavali from us');
    await type('wish-name', 'Suresh');
    await type('wish-line2', '& family');
    await tester.fling(list, const Offset(0, 2000), 3000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(captionOnCard(), 'Shubh Deepavali from us', reason: 'the user\'s own caption survives a language change');
    final card = tester.widget<WishCard>(find.byType(WishCard).first).data;
    expect((card.name, card.line2), ('Suresh', '& family'));

    // A ready-made wish replaces the message. (Close the keyboard first, or the list scrolls back to the field.)
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await reveal(find.textContaining('Let light win over darkness'));
    await tester.tap(find.textContaining('Let light win over darkness'));
    await tester.pumpAndSettle();
    expect(tester.widget<WishCard>(find.byType(WishCard).first).data.message, startsWith('Let light win'));

    await _close(tester);
    expect(WishProfile.name, 'Suresh');
  });

  testWidgets('editor: every theme and layout can be chosen', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const WishEditorScreen(id: 'diwali')));
    await tester.pumpAndSettle();
    WishCardData card() => tester.widget<WishCard>(find.byType(WishCard).first).data;
    expect(card().theme.id, 'diwali-night');
    expect(card().layout, WishLayout.darshan);

    await tester.tap(find.text('Golden Lakshmi'));
    await tester.pumpAndSettle();
    expect((card().theme.id, card().layout), ('diwali-gold', WishLayout.banner));

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('wish-layouts')),
      find.byKey(const ValueKey('wish-design-list')),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    for (final layout in WishLayout.values) {
      await tester.dragUntilVisible(
        find.text(layout.en),
        find.byKey(const ValueKey('wish-layouts')),
        const Offset(-80, 0),
      );
      await tester.tap(find.text(layout.en));
      await tester.pumpAndSettle();
      expect(card().layout, layout);
      expect(tester.takeException(), isNull);
    }
    // The chosen layout stays when the theme changes.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('wish-themes')),
      find.byKey(const ValueKey('wish-design-list')),
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Rangoli'),
      find.byKey(const ValueKey('wish-themes')),
      const Offset(-80, 0),
    );
    await tester.tap(find.text('Rangoli'));
    await tester.pumpAndSettle();
    expect((card().theme.id, card().layout), ('diwali-rangoli', WishLayout.text));
    await _close(tester);
  });

  testWidgets('editor: the photo is picked, kept on the phone and removed', (tester) async {
    _phone(tester);
    final file = await _photoFile(tester);
    var picks = 0;
    await tester.pumpWidget(
      _app(
        const WishEditorScreen(id: 'daily'),
        picker: () async {
          picks++;
          return file;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<WishCard>(find.byType(WishCard).first).data.caption, 'Good morning');

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wish-add-photo')));
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(WishProfile.photo?.path, file.path);
    expect((tester.widget<WishCard>(find.byType(WishCard).first).data.photo as FileImage?)?.file.path, file.path);
    expect(find.textContaining('Drag or pinch'), findsOneWidget);

    // Zoom with the slider; the view is remembered.
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<WishCard>(find.byType(WishCard).first).data.view.scale, greaterThan(1));
    expect(WishProfile.view.scale, greaterThan(1));

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(WishProfile.photo, isNull);
    expect(file.existsSync(), isFalse, reason: 'the private copy is deleted');
    expect(tester.widget<WishCard>(find.byType(WishCard).first).data.photo, isNull);
    await _close(tester);
  });

  testWidgets('Home card names the coming festival', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: WishesPromoCard()), now: DateTime(2026, 11, 20)));
    await tester.pumpAndSettle();
    expect(find.text('Kartik Purnima wishes'), findsOneWidget);
    expect(find.textContaining('In 4 days'), findsOneWidget);
  });

  testWidgets('Home card offers the daily card when no festival is near', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: WishesPromoCard()), now: DateTime(2027, 2, 1)));
    await tester.pumpAndSettle();
    expect(find.text('Festival wishes'), findsOneWidget);
  });
}
