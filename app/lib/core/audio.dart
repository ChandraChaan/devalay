import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'api.dart';
import 'downloads.dart';
import 'models.dart';
import 'storage.dart';

/// One shared player with a queue, lock-screen controls (via just_audio_background),
/// offline playback of downloaded tracks and a sleep timer.
///
/// A track that can't be streamed (offline, a 404, or Wikimedia answering 429 Too Many Requests)
/// must never crash the app: load and playback errors are caught here and reported on [errors],
/// which the app shell shows as a snackbar.
class AudioController {
  AudioController(this._api, this._downloads) {
    // Errors while a queue plays on (the next track fails to load) arrive on this stream; with no
    // onError listener they would be uncaught and Crashlytics would record a fatal crash.
    _events = player.playbackEventStream.listen((_) {}, onError: _failed);
    // Moving to another song in the loaded queue fails quietly (no exception): it only shows up
    // here, as an error code on a playback event.
    _playerErrors = player.errorStream.listen(_failed);
  }

  final Api _api;
  final DownloadStore _downloads;
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
    final local = _downloads.localPath(t.id);
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

  Future<void> playQueue(List<Track> tracks, {int index = 0}) async {
    if (tracks.isEmpty) return;
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

  void dispose() {
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
  final c = AudioController(ref.read(apiProvider), ref.read(downloadsProvider.notifier));
  ref.onDispose(c.dispose);
  return c;
});

/// Sent with every stream request; names the app as Wikimedia's User-Agent policy asks.
const userAgent = 'Devalay/1.5 (https://github.com/ChandraChaan/devalay)';

final currentTrackProvider = StreamProvider<Track?>((ref) => ref.watch(audioProvider).currentTrack);
final playingProvider = StreamProvider<bool>((ref) => ref.watch(audioProvider).player.playingStream);
