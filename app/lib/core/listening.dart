import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase.dart';
import 'models.dart';
import 'providers.dart';
import 'storage.dart';

/// The whole catalogue in one request (the same file the static site exports for "all tracks").
final allTracksProvider = FutureProvider<List<Track>>(
  (ref) => ref.watch(tracksProvider((kind: null, deity: null)).future),
);

/// Most played tracks in the app's own usage log (24–27 Nov 2026), ringtones left out: Gayatri,
/// Ganpati aarti, Om Namah Shivaya, Mahamrityunjaya, Lakshmi aarti, Vishnu and Hanuman songs...
/// Remote Config `popular_tracks` ("1,5,4") replaces the list without an app update.
const defaultPopularTrackIds = [1, 5, 4, 3, 6, 38, 36, 2, 7, 8, 28, 30];

/// Parses Remote Config's comma-separated ids; anything unreadable gives the default list.
@visibleForTesting
List<int> parseTrackIds(String raw) {
  final ids = [
    for (final s in raw.split(','))
      if (int.tryParse(s.trim()) case final id? when id > 0) id,
  ];
  return ids.isEmpty ? defaultPopularTrackIds : ids;
}

List<int> _popularIds() {
  if (!FirebaseServices.enabled) return defaultPopularTrackIds;
  try {
    // The value activated at an earlier launch (updateProvider fetches at startup), so the row
    // never waits on the network.
    return parseTrackIds(FirebaseRemoteConfig.instance.getString('popular_tracks'));
  } catch (_) {
    return defaultPopularTrackIds;
  }
}

/// Picks [ids] out of [all], in the order given, skipping ids the catalogue no longer has.
List<Track> tracksByIds(List<Track> all, Iterable<int> ids) {
  final byId = {for (final t in all) t.id: t};
  return [for (final id in ids) ?byId[id]];
}

final popularTracksProvider = FutureProvider<List<Track>>((ref) async {
  final all = await ref.watch(allTracksProvider.future);
  return tracksByIds(all, _popularIds());
});

/// Telugu keerthanalu: Annamacharya, Ramadasu, Tyagaraja and the Telugu stotra albums, by slug.
const teluguKeerthanaSlugs = [
  'srinivasa-thiruvenkata',
  'annamacharya-brahma-kadigina-paadamu',
  'annamacharya-jo-achyutananda',
  'annamacharya-shriman-narayana',
  'nagumomu-tyagaraja',
  'ramadasu-bhajans-balamurali',
  'annamacharya-greatest-mss',
  'pb-sreenivas-devotional',
  'vishnu-melodies-mss',
  'shiva-songs-mss',
  'ramadasu-keerthanalu-balamurali',
  'annamacharya-samkirtanas-mss',
  'bhaja-govindam-mss',
];

final teluguSongsProvider = FutureProvider<List<Track>>((ref) async {
  final all = await ref.watch(allTracksProvider.future);
  final bySlug = {for (final t in all) t.slug: t};
  return [for (final s in teluguKeerthanaSlugs) ?bySlug[s]];
});

final ringtoneTracksProvider = FutureProvider<List<Track>>(
  (ref) => ref.watch(tracksProvider((kind: 'ringtone', deity: null)).future),
);

/// A track short enough to repeat as japa: a mantra clip of at most a minute (Gayatri,
/// Mahamrityunjaya, Om Namah Shivaya), not the longer Vedic chants or stotra albums.
bool isChantable(Track t) => t.kind == 'mantra' && t.durationSec > 0 && t.durationSec <= 60;

final chantMantrasProvider = FutureProvider<List<Track>>((ref) async {
  final all = await ref.watch(allTracksProvider.future);
  return all.where(isChantable).toList();
});

/// Tracks the user started, newest first; ringtone previews are left out.
class RecentTracks extends Notifier<List<int>> {
  static const _key = 'recent_tracks';
  static const max = 12;

  @override
  List<int> build() => [...?(Boxes.prefs.get(_key) as List?)?.whereType<int>()];

  void add(Track t) {
    if (t.kind == 'ringtone') return;
    final next = [t.id, ...state.where((id) => id != t.id)].take(max).toList();
    if (listEquals(next, state)) return;
    state = next;
    Boxes.prefs.put(_key, next);
  }
}

final recentTrackIdsProvider = NotifierProvider<RecentTracks, List<int>>(RecentTracks.new);

final recentTracksProvider = FutureProvider<List<Track>>((ref) async {
  final ids = ref.watch(recentTrackIdsProvider);
  if (ids.isEmpty) return const [];
  final all = await ref.watch(allTracksProvider.future);
  return tracksByIds(all, ids);
});
