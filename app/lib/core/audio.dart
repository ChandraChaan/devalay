import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'downloads.dart';
import 'listening.dart';
import 'models.dart';
import 'storage.dart';
import 'usage.dart';

/// One shared player with a queue, lock-screen controls (via just_audio_background),
/// offline playback of downloaded tracks and a sleep timer.
///
/// A track that can't be streamed (offline, a 404, or Wikimedia answering 429 Too Many Requests)
/// must never crash the app: load and playback errors are caught here and reported on [errors],
/// which the app shell shows as a snackbar.
class AudioController {
  AudioController(this._api, this._downloads, {this.onStarted}) {
    // Errors while a queue plays on (the next track fails to load) arrive on this stream; with no
    // onError listener they would be uncaught and Crashlytics would record a fatal crash.
    _events = player.playbackEventStream.listen((_) {}, onError: _failed);
    // Moving to another song in the loaded queue fails quietly (no exception): it only shows up
    // here, as an error code on a playback event.
    _playerErrors = player.errorStream.listen(_failed);
  }

  final Api _api;
  final DownloadStore _downloads;

  /// Called with each track the user starts (for "Continue listening").
  final void Function(Track)? onStarted;
  // Request headers go straight to ExoPlayer: just_audio's local header proxy would be plain http
  // to localhost, which the network security config doesn't allow.
  final player = AudioPlayer(useProxyForRequestHeaders: false);
  late final StreamSubscription<PlaybackEvent> _events;
  late final StreamSubscription<PlayerException> _playerErrors;
  final _errors = StreamController<Object>.broadcast();
  DateTime _lastError = DateTime(2000);

  /// A track failed to load or play.
  Stream<Object> get errors => _errors.stream;
  List<Track> queue = const [];
  Timer? _sleepTimer;
  DateTime? sleepAt;

  Stream<Track?> get currentTrack => player.sequenceStateStream.map((s) {
    final tag = s.currentSource?.tag;
    return tag is MediaItem ? _track(tag) : null;
  });

  Track? get current {
    final tag = player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? _track(tag) : null;
  }

  // The MediaItem crosses the platform channel to the Android media session, so it carries only
  // plain values; the Track itself is looked up here. (A Track object in `extras` made the
  // session update fail, leaving the lock screen with no title.)
  Track? _track(MediaItem item) => queue.where((t) => '${t.id}' == item.id).firstOrNull;

  AudioSource _source(Track t) {
    final local = _chantFiles[t.id] ?? _downloads.localPath(t.id);
    final uri = local != null && File(local).existsSync() ? Uri.file(local) : Uri.parse(t.audioUrl);
    return AudioSource.uri(
      uri,
      // Wikimedia Commons rate-limits (HTTP 429) clients without a descriptive User-Agent.
      headers: uri.isScheme('file') ? null : const {'User-Agent': userAgent},
      tag: MediaItem(
        id: '${t.id}',
        title: t.label(Prefs.load(Boxes.prefs).language),
        artist: t.artist.isEmpty ? 'Devalay' : t.artist,
        album: 'Devalay',
        artUri: t.artworkUrl.isEmpty ? null : Uri.parse(t.artworkUrl),
      ),
    );
  }

  /// Plays [tracks] from [index]. [from] names the row or screen it was started from, for the
  /// usage log ("popular", "continue", "home_today"...).
  Future<void> playQueue(List<Track> tracks, {int index = 0, String? from}) async {
    if (index < tracks.length) {
      Usage.record('audio_play', item: '${tracks[index].kind}:${tracks[index].id}');
      if (from != null) Usage.record('play_from', item: from);
      onStarted?.call(tracks[index]);
    }
    if (tracks.isEmpty) return;
    // Anything the user starts by hand ends a chant in progress.
    if (from != 'chant') await _endChant();
    final same =
        queue.length == tracks.length && Iterable.generate(tracks.length).every((i) => queue[i].id == tracks[i].id);
    try {
      if (same) {
        await player.seek(Duration.zero, index: index);
      } else {
        queue = List.unmodifiable(tracks);
        await player.setAudioSources(tracks.map(_source).toList(), initialIndex: index);
      }
    } catch (e) {
      // Forget the queue so tapping the track again reloads it instead of seeking a dead source.
      queue = const [];
      _failed(e);
      return;
    }
    unawaited(player.play().catchError(_failed));
    _api.post('/tracks/${tracks[index].id}/play').catchError((_) {});
  }

  Future<void> playOne(Track t) => playQueue([t]);

  Future<void> toggle() async {
    try {
      player.playing ? await player.pause() : await player.play();
    } catch (e) {
      _failed(e);
    }
  }

  void _failed(Object e, [StackTrace? _]) {
    // Expected in the field (network, server limits): log it, tell the user, carry on.
    // A newer load interrupting an older one is not a failure.
    debugPrint('Audio error: $e');
    if (e is PlayerInterruptedException) return;
    // One failure can surface twice (a thrown load error and an error event): tell the user once.
    final now = DateTime.now();
    if (now.difference(_lastError) < const Duration(seconds: 2)) return;
    _lastError = now;
    if (!_errors.isClosed) _errors.add(e);
  }

  // ---- Chanting: one short mantra, repeated a set number of times (11, 21, 108). ----

  /// The chant in progress (or just finished), for the chant screen and the mini player.
  final chant = ValueNotifier<ChantProgress?>(null);
  StreamSubscription<PositionDiscontinuity>? _chantSub;
  final _chantFiles = <int, String>{};

  /// Repeats [t] [times] times. The clip is saved to the cache first, so 108 rounds don't fetch
  /// it 108 times (and a weak connection can't stop the chant halfway).
  Future<void> startChant(Track t, int times, {Future<String> Function(Track)? fetchFile}) async {
    await _endChant();
    chant.value = ChantProgress(track: t, target: times, done: 0, preparing: true);
    try {
      if (_downloads.localPath(t.id) == null) _chantFiles[t.id] = await (fetchFile ?? _cacheClip)(t);
    } catch (e) {
      chant.value = null;
      _failed(e);
      return;
    }
    if (chant.value?.track.id != t.id) return; // cancelled while the clip was loading
    Usage.record('chant_start', item: '${t.id}:$times');
    // Force a fresh source so the cached file is used even if this track is already loaded.
    queue = const [];
    try {
      await player.setLoopMode(LoopMode.one);
    } catch (_) {}
    await playQueue([t], from: 'chant');
    if (queue.isEmpty) {
      chant.value = null; // failed to load; _failed has told the user
      return;
    }
    chant.value = ChantProgress(track: t, target: times, done: 0);
    _chantSub = player.positionDiscontinuityStream.listen((d) {
      if (d.reason != PositionDiscontinuityReason.autoAdvance) return;
      final c = chant.value;
      if (c == null || c.finished) return;
      final done = c.done + 1;
      chant.value = c.copyWith(done: done);
      if (done >= c.target) unawaited(_completeChant(c.target));
    });
  }

  static Future<String> _cacheClip(Track t) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/chant');
    await dir.create(recursive: true);
    final ext = Uri.parse(t.audioUrl).path.split('.').last;
    final file = File('${dir.path}/${t.id}.${ext.length <= 4 ? ext : 'mp3'}');
    if (await file.exists() && await file.length() > 0) return file.path;
    final part = File('${file.path}.part');
    await Dio().download(
      t.audioUrl,
      part.path,
      options: Options(headers: const {'User-Agent': userAgent}, receiveTimeout: const Duration(seconds: 60)),
    );
    await part.rename(file.path);
    return file.path;
  }

  Future<void> _completeChant(int times) async {
    await _chantSub?.cancel();
    _chantSub = null;
    Usage.record('chant_done', item: '$times');
    try {
      await player.setLoopMode(LoopMode.off);
      await player.pause();
      await player.seek(Duration.zero);
    } catch (_) {}
    final total = (Boxes.stats.get('chants_total', defaultValue: 0) as int) + times;
    unawaited(Boxes.stats.put('chants_total', total));
  }

  /// Stops counting (the user stopped, or started something else).
  Future<void> stopChant() async {
    final c = chant.value;
    if (c != null && !c.finished && !c.preparing) Usage.record('chant_stop', item: '${c.done}/${c.target}');
    await _endChant();
    try {
      await player.pause();
    } catch (_) {}
  }

  Future<void> _endChant() async {
    if (chant.value == null && _chantSub == null) return;
    await _chantSub?.cancel();
    _chantSub = null;
    chant.value = null;
    try {
      if (player.loopMode == LoopMode.one) await player.setLoopMode(LoopMode.off);
    } catch (_) {}
  }

  void dispose() {
    _chantSub?.cancel();
    chant.dispose();
    _events.cancel();
    _playerErrors.cancel();
    _errors.close();
    player.dispose();
  }

  Future<void> cycleLoop() async {
    final next = {LoopMode.off: LoopMode.all, LoopMode.all: LoopMode.one, LoopMode.one: LoopMode.off}[player.loopMode]!;
    await player.setLoopMode(next);
  }

  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    sleepAt = after == null ? null : DateTime.now().add(after);
    if (after != null) _sleepTimer = Timer(after, () => player.pause());
  }

  Future<void> stop() async {
    await player.stop();
    queue = const [];
  }
}

final audioProvider = Provider<AudioController>((ref) {
  final c = AudioController(
    ref.read(apiProvider),
    ref.read(downloadsProvider.notifier),
    onStarted: (t) => ref.read(recentTrackIdsProvider.notifier).add(t),
  );
  ref.onDispose(c.dispose);
  return c;
});

/// Sent with every stream request; names the app as Wikimedia's User-Agent policy asks.
const userAgent = 'Devalay/1.5 (https://github.com/ChandraChaan/devalay)';

final currentTrackProvider = StreamProvider<Track?>((ref) => ref.watch(audioProvider).currentTrack);
final playingProvider = StreamProvider<bool>((ref) => ref.watch(audioProvider).player.playingStream);

@immutable
class ChantProgress {
  const ChantProgress({required this.track, required this.target, required this.done, this.preparing = false});
  final Track track;
  final int target, done;

  /// The clip is still being fetched.
  final bool preparing;
  bool get finished => done >= target;
  ChantProgress copyWith({int? done}) => ChantProgress(track: track, target: target, done: done ?? this.done);
}
