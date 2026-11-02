import 'package:audioplayers/audioplayers.dart' as ap;

/// Short Mandir sound effects bundled with the app (original, CC0). They use a
/// separate lightweight player so they never interrupt the main bhakti queue.
class Sfx {
  static final _pool = <String, ap.AudioPlayer>{};
  // Mix with the bhakti player instead of taking audio focus (which would pause it).
  static final _context = ap.AudioContextConfig(focus: ap.AudioContextConfigFocus.mixWithOthers).build();

  static Future<void> play(String name, {double volume = 1.0, bool loop = false}) async {
    final player = _pool.putIfAbsent(name, () => ap.AudioPlayer(playerId: 'sfx-$name')..setAudioContext(_context));
    await player.setReleaseMode(loop ? ap.ReleaseMode.loop : ap.ReleaseMode.stop);
    await player.stop();
    await player.play(ap.AssetSource('sounds/$name.m4a'), volume: volume);
  }

  static Future<void> stop(String name) async => _pool[name]?.stop();

  static Future<void> stopAll() async {
    for (final p in _pool.values) {
      await p.stop();
    }
  }
}
