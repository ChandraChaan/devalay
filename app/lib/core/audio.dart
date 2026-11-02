import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'api.dart';
import 'downloads.dart';
import 'models.dart';

/// One shared player with a queue, lock-screen controls (via just_audio_background),
/// offline playback of downloaded tracks and a sleep timer.
class AudioController {
  AudioController(this._api, this._downloads);

  final Api _api;
  final DownloadStore _downloads;
  final player = AudioPlayer();
  List<Track> queue = const [];
  Timer? _sleepTimer;
  DateTime? sleepAt;

  Stream<Track?> get currentTrack => player.sequenceStateStream.map((s) {
    final tag = s.currentSource?.tag;
    return tag is MediaItem ? tag.extras!['track'] as Track : null;
  });

  Track? get current {
    final tag = player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag.extras!['track'] as Track : null;
  }

  AudioSource _source(Track t) {
    final local = _downloads.localPath(t.id);
    final uri = local != null && File(local).existsSync() ? Uri.file(local) : Uri.parse(t.audioUrl);
    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: '${t.id}',
        title: t.titleHi.isNotEmpty ? '${t.title} · ${t.titleHi}' : t.title,
        artist: t.artist.isEmpty ? 'Devalay' : t.artist,
        album: 'Devalay',
        artUri: t.artworkUrl.isEmpty ? null : Uri.parse(t.artworkUrl),
        extras: {'track': t},
      ),
    );
  }

  Future<void> playQueue(List<Track> tracks, {int index = 0}) async {
    if (tracks.isEmpty) return;
    final same =
        queue.length == tracks.length && Iterable.generate(tracks.length).every((i) => queue[i].id == tracks[i].id);
    if (same) {
      await player.seek(Duration.zero, index: index);
    } else {
      queue = List.unmodifiable(tracks);
      await player.setAudioSources(tracks.map(_source).toList(), initialIndex: index);
    }
    unawaited(player.play());
    _api.post('/tracks/${tracks[index].id}/play').catchError((_) {});
  }

  Future<void> playOne(Track t) => playQueue([t]);

  Future<void> toggle() => player.playing ? player.pause() : player.play();

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
  ref.onDispose(c.player.dispose);
  return c;
});

final currentTrackProvider = StreamProvider<Track?>((ref) => ref.watch(audioProvider).currentTrack);
final playingProvider = StreamProvider<bool>((ref) => ref.watch(audioProvider).player.playingStream);
