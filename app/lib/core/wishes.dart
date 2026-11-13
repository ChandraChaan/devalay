import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'i18n.dart';
import 'models.dart';
import 'providers.dart';
import 'storage.dart';
import 'temples.dart' show loc;
import 'theme.dart';

/// Festival wishes: greeting cards the user personalises with a name and a photo and shares as an
/// image. Which festivals exist, their themes, captions and ready-made wishes are all data.
///
/// The catalogue ships in the app (assets/data/wishes.json) and the same file is published with
/// the static API, so a new festival or theme reaches users without an app update. Layouts and the
/// decorations a theme can ask for are drawn in code (widgets/wish_card.dart, widgets/wish_art.dart).
///
/// The user's photo never leaves the phone: it is copied into the app's private folder, drawn on
/// the card, and only the finished image goes to the app the user shares it with.

/// How a card arranges the deity, the photo and the text.
enum WishLayout {
  darshan('darshan', 'Darshan', 'दर्शन', 'దర్శనం'),
  banner('banner', 'Banner', 'बैनर', 'బ్యానర్'),
  badge('badge', 'Full picture', 'पूरा चित्र', 'పూర్తి చిత్రం'),
  split('split', 'Split', 'दो भाग', 'రెండు భాగాలు'),
  portrait('portrait', 'Portrait', 'पोर्ट्रेट', 'పోర్ట్రెయిట్'),
  text('text', 'Text only', 'केवल शब्द', 'అక్షరాలు మాత్రమే');

  const WishLayout(this.id, this.en, this.hi, this.te);
  final String id, en, hi, te;

  String label(String lang) => t3(lang, en, hi, te);

  /// The layout a catalogue names; a name from a newer catalogue falls back to [darshan].
  static WishLayout byId(Object? id) => values.where((l) => l.id == id).firstOrNull ?? darshan;
}

/// Decorations a theme can name. A name this build does not know is simply not drawn, so a newer
/// catalogue never breaks an older app.
abstract final class WishMotifs {
  static const top = {'toran', 'sparkles', 'kites', 'bells', 'moon', 'crescent', 'sun', 'feather', 'flags'};
  static const bottom = {'diyas', 'rangoli', 'lotus', 'pot', 'kolam', 'rakhi', 'garland'};
  static const backdrop = {'mandala', 'rays', 'bokeh', 'colors', 'stars'};
}

class WishTheme {
  WishTheme(this._j)
    : colors = [for (final c in _j['colors'] as List? ?? const []) Palette.hex('$c')],
      accent = Palette.hex('${_j['accent'] ?? ''}', fallback: Palette.gold),
      ink = Palette.hex('${_j['ink'] ?? ''}', fallback: const Color(0xFFFFFFFF)),
      layout = WishLayout.byId(_j['layout']);
  final Map _j;

  /// Background gradient, top to bottom.
  final List<Color> colors;

  /// Borders, ornaments and the caption.
  final Color accent;

  /// Body text.
  final Color ink;

  /// The layout this theme was designed for; the user can pick any other.
  final WishLayout layout;

  String get id => '${_j['id']}';
  String name(String lang) => loc(_j['name'], lang);
  String get top => '${_j['top'] ?? ''}';
  String get bottom => '${_j['bottom'] ?? ''}';
  String get backdrop => '${_j['backdrop'] ?? ''}';

  /// A deity this theme shows instead of the festival's own (Rama on a Dussehra card).
  String? get deity => _j['deity'] is String ? _j['deity'] as String : null;

  /// Serif (Tiro) or sans (Mukta) caption.
  bool get serif => _j['font'] != 'sans';

  /// Whether the background is dark, which decides how panels and scrims are tinted.
  bool get dark => colors.first.computeLuminance() + colors.last.computeLuminance() < 0.7;

  bool get valid => _j['id'] is String && colors.length >= 2;
}

/// A caption or a ready-made wish. It can be limited to hours of the day or a weekday, which is
/// how the daily set says "Good morning" before noon and "Good night" after dark.
class WishText {
  WishText(this._j);
  final Map _j;

  String text(String lang) => loc(_j['text'] ?? _j, lang);

  /// Monday is 1, as in [DateTime.weekday].
  int? get weekday => _j['weekday'] is int ? _j['weekday'] as int : null;

  bool get conditional => weekday != null || _j['hours'] is List;

  bool matches(DateTime now) {
    if (weekday != null && weekday != now.weekday) return false;
    final hours = _j['hours'];
    if (hours is List && hours.length == 2 && hours.every((h) => h is int)) {
      final from = hours[0] as int, to = hours[1] as int;
      // [20, 4] wraps past midnight.
      return from <= to ? now.hour >= from && now.hour < to : now.hour >= from || now.hour < to;
    }
    return true;
  }

  bool get valid => text('en').isNotEmpty;
}

class WishFestival {
  WishFestival(this._j)
    : themes = [
        for (final t in _j['themes'] as List? ?? const [])
          if (t is Map) WishTheme(t),
      ].where((t) => t.valid).toList(),
      captions = _texts(_j['captions']),
      wishes = _texts(_j['wishes']);
  final Map _j;
  final List<WishTheme> themes;
  final List<WishText> captions, wishes;

  static List<WishText> _texts(Object? json) => [
    for (final t in json as List? ?? const [])
      if (t is Map) WishText(t),
  ].where((t) => t.valid).toList();

  String get id => '${_j['id']}';

  /// `festival` follows the calendar, `daily` is for every day, `occasion` has no date.
  String get kind => '${_j['kind'] ?? 'festival'}';
  bool get daily => kind == 'daily';
  String get emoji => '${_j['emoji'] ?? '🪔'}';
  String name(String lang) => loc(_j['name'], lang);

  /// Sacred syllable drawn when no painting is shown ("ॐ", "श्री").
  String get symbol => '${_j['symbol'] ?? 'ॐ'}';

  /// Calendar festivals this set is for, by [Festival.slug] or [Festival.kind].
  List<String> get match => [for (final m in _j['match'] as List? ?? const []) '$m'];

  /// How many days the festival lasts from its calendar date.
  int get days => _j['days'] is int ? (_j['days'] as int).clamp(1, 30) : 1;

  /// The deity whose painting the card shows on [day]; empty for none.
  String deity(DateTime day) {
    final week = _j['deity_by_weekday'];
    if (week is List && week.length == 7) return '${week[day.weekday - 1]}';
    return '${_j['deity'] ?? ''}';
  }

  bool covers(Festival f) => match.contains(f.slug) || match.contains(f.kind);

  /// A fixed day of the Gregorian year (`"on": "01-01"`), for sets that do not follow the panchang.
  DateTime? _fixed(int year) {
    final m = RegExp(r'^(\d\d)-(\d\d)$').firstMatch('${_j['on'] ?? ''}');
    return m == null ? null : DateTime(year, int.parse(m[1]!), int.parse(m[2]!));
  }

  /// The first day of the current or next celebration on or after [today], if the calendar knows it.
  DateTime? nextDate(Iterable<Festival> calendar, DateTime today) {
    final day = DateUtils.dateOnly(today);
    if (daily) return day;
    final starts = [
      for (final f in calendar)
        if (covers(f)) DateUtils.dateOnly(f.date),
      for (final y in [day.year - 1, day.year, day.year + 1]) ?_fixed(y),
    ]..sort();
    return starts.where((s) => !DateUtils.addDaysToDate(s, days - 1).isBefore(day)).firstOrNull;
  }

  /// Captions with the ones that fit [now] first; the first is the card's default.
  List<WishText> captionsFor(DateTime now) => _fitting(captions, now);
  List<WishText> wishesFor(DateTime now) => _fitting(wishes, now);

  static List<WishText> _fitting(List<WishText> all, DateTime now) => [
    ...all.where((t) => t.conditional && t.matches(now)),
    ...all.where((t) => !t.conditional),
  ];

  bool get valid => _j['id'] is String && themes.isNotEmpty && captions.isNotEmpty && name('en').isNotEmpty;
}

class WishCatalog {
  WishCatalog(Map json)
    : schema = json['schema'] is int ? json['schema'] as int : 0,
      version = json['version'] is int ? json['version'] as int : 0,
      updated = DateTime.tryParse('${json['updated']}'),
      festivals = [
        for (final f in json['festivals'] as List? ?? const [])
          if (f is Map) WishFestival(f),
      ].where((f) => f.valid).toList();

  /// The catalogue layout this app understands. A published catalogue with another schema is ignored.
  static const supportedSchema = 1;

  final int schema, version;
  final DateTime? updated;
  final List<WishFestival> festivals;

  WishFestival? byId(String id) => festivals.where((f) => f.id == id).firstOrNull;

  /// The set to offer for a calendar festival, if there is one.
  WishFestival? forFestival(Festival f) => festivals.where((w) => w.covers(f)).firstOrNull;

  WishFestival? get daily => festivals.where((f) => f.daily).firstOrNull;
}

/// A set with the day its celebration starts, as shown in the list.
typedef DatedWish = ({WishFestival festival, DateTime? date});

/// Calendar sets in the order they come up from [today], then the ones with no known date.
/// The daily set is not included; it has its own place on the screen.
List<DatedWish> upcomingWishes(WishCatalog catalog, Iterable<Festival> calendar, DateTime today) {
  final dated = <DatedWish>[
    for (final f in catalog.festivals)
      if (!f.daily) (festival: f, date: f.nextDate(calendar, today)),
  ];
  return [
    ...dated.where((d) => d.date != null).toList()..sort((a, b) => a.date!.compareTo(b.date!)),
    ...dated.where((d) => d.date == null),
  ];
}

/// Days from [today] until [date]; zero or less while the festival is on.
int daysUntil(DateTime date, DateTime today) => DateUtils.dateOnly(date).difference(DateUtils.dateOnly(today)).inDays;

Future<WishCatalog> loadBundledWishes() async =>
    WishCatalog(jsonDecode(await rootBundle.loadString('assets/data/wishes.json')) as Map);

/// The bundled catalogue at once, then the published one if it is newer.
final wishCatalogProvider = StreamProvider<WishCatalog>((ref) async* {
  final bundled = await loadBundledWishes();
  yield bundled;
  try {
    final remote = WishCatalog(await ref.read(apiProvider).get('/wishes') as Map);
    if (remote.schema == WishCatalog.supportedSchema &&
        remote.version > bundled.version &&
        remote.festivals.isNotEmpty) {
      yield remote;
    }
  } catch (_) {
    // Offline, or a server without the catalogue: the bundled copy stays.
  }
});

/// The current time; tests replace it to see the screens on a festival day.
final wishClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// This year's and next year's festivals, as far as they have loaded. Offline, the list may be
/// empty; wishes are then listed in catalogue order.
final wishCalendarProvider = Provider<List<Festival>>((ref) {
  final year = ref.watch(wishClockProvider)().year;
  return [...?ref.watch(festivalsProvider(year)).value, ...?ref.watch(festivalsProvider(year + 1)).value];
});

/// Public-domain paintings of [deity] (empty for all of them). A deity without paintings, or no
/// connection, gives an empty list and the card draws the deity's syllable instead.
final wishPaintingsProvider = FutureProvider.family<List<Wallpaper>, String>((ref, deity) async {
  try {
    return await ref.watch(wallpapersProvider(deity.isEmpty ? null : deity).future);
  } catch (_) {
    return const [];
  }
});

/// How the photo sits inside its frame: zoom, and which part of it shows.
@immutable
class PhotoView {
  const PhotoView({this.scale = 1, this.x = 0, this.y = -0.3});

  /// Faces are usually in the upper half, so that is where a new photo is centred.
  static const initial = PhotoView();
  static const maxScale = 4.0;

  static PhotoView parse(Object? json) => json is List && json.length == 3 && json.every((v) => v is num)
      ? PhotoView(scale: (json[0] as num).toDouble(), x: (json[1] as num).toDouble(), y: (json[2] as num).toDouble())
      : initial;

  /// 1 fills the frame; larger zooms in.
  final double scale;

  /// The point of the photo kept in view, from -1 (left, top) to 1 (right, bottom).
  final double x, y;

  PhotoView copyWith({double? scale, double? x, double? y}) => PhotoView(
    scale: (scale ?? this.scale).clamp(1, maxScale),
    x: (x ?? this.x).clamp(-1, 1),
    y: (y ?? this.y).clamp(-1, 1),
  );

  List<double> toJson() => [scale, x, y];
}

/// The sender's name and photo, remembered on this phone for the next card.
class WishProfile {
  static const _name = 'wish_name', _photo = 'wish_photo', _view = 'wish_photo_view';

  /// Replaces the on-device box in tests, so no storage write is left waiting when a test ends.
  @visibleForTesting
  static Map<String, Object?>? memory;

  static Object? _get(String key) => memory != null ? memory![key] : Boxes.prefs.get(key);

  static Future<void> _set(String key, Object? value) async {
    if (memory != null) {
      value == null ? memory!.remove(key) : memory![key] = value;
    } else if (value == null) {
      await Boxes.prefs.delete(key);
    } else {
      await Boxes.prefs.put(key, value);
    }
  }

  static String get name => _get(_name) as String? ?? '';
  static Future<void> setName(String name) => _set(_name, name.trim());

  /// The remembered photo, if its file is still there.
  static File? get photo {
    final path = _get(_photo) as String?;
    return path != null && File(path).existsSync() ? File(path) : null;
  }

  static PhotoView get view => PhotoView.parse(_get(_view));
  static Future<void> setView(PhotoView view) => _set(_view, view.toJson());

  /// Remembers [file] (or forgets the photo) and deletes the previous private copy at once.
  static Future<void> setPhoto(File? file) {
    final old = _get(_photo) as String?;
    if (old != null && old != file?.path) {
      try {
        File(old).deleteSync();
      } catch (_) {
        // Already gone.
      }
    }
    return Future.wait([_set(_photo, file?.path), _set(_view, null)]);
  }
}

/// Lets the user choose a photo and returns a private copy of it, or null if they cancelled.
typedef WishPhotoPicker = Future<File?> Function();

/// Opens the system photo picker, which needs no storage permission because the user hands over
/// one picture. The copy stays in the app's own folder and is not sent anywhere.
final wishPhotoPickerProvider = Provider<WishPhotoPicker>(
  (ref) => () async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null) return null;
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/wishes');
    await dir.create(recursive: true);
    final ext = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    // A new name each time, so the image cache never shows the previous photo.
    return File(picked.path).copy('${dir.path}/photo-${DateTime.now().millisecondsSinceEpoch}.$ext');
  },
);
