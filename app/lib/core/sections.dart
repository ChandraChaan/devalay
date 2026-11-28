import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'json_asset.dart';
import 'storage.dart';
import 'usage.dart';

/// The Ringtones, Wallpapers and WhatsApp Status catalogue (assets/data/sections.json, built by
/// backend/scripts/build_sections_media.py). Every item is public domain, CC0, CC BY or CC BY-SA and
/// carries its credit. In each section the five items with a `premium` rank are the Premium collection;
/// everything else is free.

/// Ranks 1-5 are Premium; null is free.
const premiumPerSection = 5;

class Credit {
  Credit(Map m)
    : author = '${m['author'] ?? ''}',
      license = '${m['license'] ?? ''}',
      licenseUrl = '${m['license_url'] ?? ''}',
      source = '${m['source'] ?? ''}',
      changes = '${m['changes'] ?? ''}';
  final String author, license, licenseUrl, source, changes;

  /// "Raja Ravi Varma · Public domain" — what CC BY asks to be shown next to the work.
  String get line => [author, license].where((s) => s.isNotEmpty).join(' · ');
}

/// Titles in English, Telugu and Hindi; other app languages fall back to English.
class Titles {
  Titles(Map? m) : en = '${m?['en'] ?? ''}', te = '${m?['te'] ?? ''}', hi = '${m?['hi'] ?? ''}';
  final String en, te, hi;
  String of(String lang) => switch (lang) {
    'te' when te.isNotEmpty => te,
    'hi' when hi.isNotEmpty => hi,
    _ => en,
  };
}

/// What every section item has: an id, a deity, tags (weekday names, festival slugs), its Premium rank.
abstract class SectionItem {
  SectionItem(Map m)
    : id = '${m['id']}',
      deity = '${m['deity'] ?? 'general'}',
      title = Titles(m['title'] as Map?),
      premiumRank = (m['premium'] as num?)?.toInt(),
      tags = [for (final t in (m['tags'] as List? ?? const [])) '$t'];
  final String id, deity;
  final Titles title;
  final int? premiumRank;
  final List<String> tags;

  /// Which section: 'wallpaper', 'ringtone' or 'status_video' (also the usage-log prefix).
  String get section;
  bool get isPremium => premiumRank != null;
}

class HdWallpaper extends SectionItem {
  HdWallpaper(super.m)
    : thumb = '${m['thumb']}',
      fhd = '${m['fhd']}',
      qhd = '${m['qhd']}',
      color = '${m['color'] ?? '#5D4037'}',
      style = '${m['style'] ?? 'classic'}',
      credit = Credit(m['credit'] as Map? ?? const {});
  final String thumb, fhd, qhd, color;

  /// 'modern' (Devalay's own designs), 'photo' (recent photographs) or 'classic' (paintings and prints).
  final String style;
  final Credit credit;
  @override
  String get section => 'wallpaper';
}

class Ringtone extends SectionItem {
  Ringtone(super.m)
    : audio = '${m['audio']}',
      notification = '${m['notification']}',
      seconds = (m['seconds'] as num?)?.toDouble() ?? 0,
      credit = Credit(m['credit'] as Map? ?? const {});
  final String audio, notification;
  final double seconds;
  final Credit credit;
  @override
  String get section => 'ringtone';
}

class StatusVideo extends SectionItem {
  StatusVideo(super.m)
    : lang = '${m['lang'] ?? 'te'}',
      text = '${m['text'] ?? ''}',
      video = '${m['video']}',
      poster = '${m['poster']}',
      seconds = (m['seconds'] as num?)?.toInt() ?? 15,
      artCredit = Credit((m['credit'] as Map?)?['art'] as Map? ?? const {}),
      audioCredit = Credit((m['credit'] as Map?)?['audio'] as Map? ?? const {});
  final String lang, text, video, poster;
  final int seconds;
  final Credit artCredit, audioCredit;
  @override
  String get section => 'status_video';
}

/// A seamless meditation soundscape (a 2-minute loop).
class MeditationSound extends SectionItem {
  MeditationSound(super.m)
    : audio = '${m['audio']}',
      seconds = (m['seconds'] as num?)?.toDouble() ?? 0,
      credit = Credit(m['credit'] as Map? ?? const {});
  final String audio;
  final double seconds;
  final Credit credit;
  @override
  String get section => 'meditation';
}

class SectionsCatalog {
  SectionsCatalog(Map json)
    : schema = (json['schema'] as num?)?.toInt() ?? 0,
      version = (json['version'] as num?)?.toInt() ?? 0,
      wallpapers = premiumFirst([for (final m in (json['wallpapers'] as List? ?? const [])) HdWallpaper(m as Map)]),
      ringtones = premiumFirst([for (final m in (json['ringtones'] as List? ?? const [])) Ringtone(m as Map)]),
      statusVideos = premiumFirst([
        for (final m in (json['status_videos'] as List? ?? const [])) StatusVideo(m as Map),
      ]),
      meditation = premiumFirst([for (final m in (json['meditation'] as List? ?? const [])) MeditationSound(m as Map)]);

  static const supportedSchema = 1;
  final int schema, version;
  final List<HdWallpaper> wallpapers;
  final List<Ringtone> ringtones;
  final List<StatusVideo> statusVideos;
  final List<MeditationSound> meditation;

  SectionItem? find(String section, String id) => switch (section) {
    'wallpaper' => wallpapers.where((w) => w.id == id).firstOrNull,
    'ringtone' => ringtones.where((r) => r.id == id).firstOrNull,
    'status_video' => statusVideos.where((v) => v.id == id).firstOrNull,
    'meditation' => meditation.where((v) => v.id == id).firstOrNull,
    _ => null,
  };
}

/// The Premium collection (by rank) first, then the free items in catalogue order.
List<T> premiumFirst<T extends SectionItem>(List<T> items) {
  final premium = items.where((i) => i.isPremium).toList()..sort((a, b) => a.premiumRank!.compareTo(b.premiumRank!));
  return [...premium, ...items.where((i) => !i.isPremium)];
}

/// Whether [item] needs Premium on this phone right now.
bool isLocked(SectionItem item, {required bool premium}) => item.isPremium && !premium;

Future<SectionsCatalog> loadBundledSections() async =>
    SectionsCatalog(await loadJsonAsset('assets/data/sections.json'));

/// The bundled catalogue at once (works offline), then the published one when it is newer, so new
/// festival packs and fixes reach installed apps without an update.
final sectionsProvider = StreamProvider<SectionsCatalog>((ref) async* {
  final bundled = await loadBundledSections();
  yield bundled;
  try {
    final remote = SectionsCatalog(await ref.read(apiProvider).get('/sections') as Map);
    if (remote.schema == SectionsCatalog.supportedSchema && remote.version > bundled.version) yield remote;
  } catch (e) {
    debugPrint('sections: using the bundled catalogue ($e)');
  }
});

// --- Today ------------------------------------------------------------------------------------------------------

const _weekdayTags = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

/// The tags that describe [day]: its weekday, morning or night, and any festival slugs in [festivals]
/// (the next few days' festivals from the home feed).
Set<String> todayTags(DateTime day, {Iterable<String> festivals = const []}) => {
  _weekdayTags[day.weekday - 1],
  if (day.hour >= 4 && day.hour < 12) 'morning',
  if (day.hour >= 19 || day.hour < 4) 'night',
  ...festivals,
};

/// Items for the "Today" row: festival matches first, then the weekday and time of day.
List<T> forToday<T extends SectionItem>(List<T> items, Set<String> tags, {int max = 8}) {
  int score(T i) => i.tags.where(tags.contains).fold(0, (s, t) => s + (_weekdayTags.contains(t) ? 1 : 3));
  final scored = [
    for (final i in items)
      if (score(i) > 0) i,
  ]..sort((a, b) => score(b).compareTo(score(a)));
  return scored.take(max).toList();
}

// --- Premium lock ----------------------------------------------------------------------------------------------

/// The usage-log id of an item: 'wallpaper:lakshmi-1930'.
String itemRef(SectionItem item) => '${item.section}:${item.id}';

/// A tap on a locked item, for the owner's funnel in the admin screen: premium_lock_tap (which item
/// made someone curious) → premium_view (from=that item) → purchase.
void logLockTap(SectionItem item) => Usage.record('premium_lock_tap', item: itemRef(item));

/// Opens Premium with [item] as its context. [log] records the lock tap first (pass false when the tap
/// was already logged, e.g. from a locked preview's Unlock button).
void openPremiumFor(BuildContext context, SectionItem item, {bool log = true}) {
  if (log) logLockTap(item);
  context.push('/premium?from=${Uri.encodeComponent(itemRef(item))}');
}

/// "wallpaper:lakshmi-1930" → ('wallpaper', 'lakshmi-1930'); null for other Premium sources.
(String, String)? parsePremiumSource(String source) {
  final i = source.indexOf(':');
  if (i <= 0) return null;
  final section = source.substring(0, i);
  if (!const {'wallpaper', 'ringtone', 'status_video', 'status_template', 'meditation'}.contains(section)) {
    return null;
  }
  return (section, source.substring(i + 1));
}

// --- Offline files ----------------------------------------------------------------------------------------------

/// Downloaded section files live in app storage (not the cache), so wallpapers, ringtones and status
/// videos keep working offline. Boxes.prefs['section_files'] maps a URL to its file name.
class SectionFiles {
  SectionFiles._();
  static const _key = 'section_files';
  static Directory? _dir;

  static Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final d = Directory('${(await getApplicationSupportDirectory()).path}/sections');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  static Map<String, String> get _index =>
      Map<String, String>.from((Boxes.prefs.get(_key, defaultValue: const {}) as Map).cast<String, String>());

  static bool isDownloaded(String url) => _index.containsKey(url);

  /// The local file for [url], downloading it first when needed.
  static Future<File> get(String url, {void Function(double progress)? onProgress}) async {
    final name = fileNameFor(url);
    final file = File('${(await dir()).path}/$name');
    if (await file.exists() && await file.length() > 0) return file;
    final part = File('${file.path}.part');
    await Dio().download(
      url,
      part.path,
      onReceiveProgress: (got, total) => total > 0 ? onProgress?.call(got / total) : null,
    );
    await part.rename(file.path);
    await Boxes.prefs.put(_key, {..._index, url: name});
    return file;
  }

  static Future<void> remove(String url) async {
    final index = _index;
    final name = index.remove(url);
    if (name != null) {
      final f = File('${(await dir()).path}/$name');
      if (await f.exists()) await f.delete();
    }
    await Boxes.prefs.put(_key, index);
  }

  /// "…/media-sections-v1/wp-lakshmi-1930-qhd.jpg" → "wp-lakshmi-1930-qhd.jpg".
  @visibleForTesting
  static String fileNameFor(String url) {
    final last = Uri.parse(url).pathSegments.lastOrNull ?? '';
    return last.isEmpty ? url.hashCode.toRadixString(16) : last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}

/// Rebuilds a section screen after a download, so "Downloaded" badges and filters update.
final sectionDownloadsTick = NotifierProvider<_Tick, int>(_Tick.new);

class _Tick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}
