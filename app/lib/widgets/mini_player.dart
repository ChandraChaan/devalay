import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/audio.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'common.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider).value;
    if (track == null) return const SizedBox.shrink();
    final playing = ref.watch(playingProvider).value ?? false;
    final audio = ref.read(audioProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: GestureDetector(
        onTap: () => context.push('/player'),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) context.push('/player');
        },
        child: Hero(
          tag: 'player-card',
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Palette.maroon, Color(0xFF8E2D0E)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 46, height: 46, child: NetImage(track.artworkUrl, radius: 12)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          track.label(uiLang(ref)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: audio.toggle,
                        icon: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      IconButton(
                        onPressed: audio.player.hasNext ? audio.player.seekToNext : null,
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  StreamBuilder<Duration>(
                    stream: audio.player.positionStream,
                    builder: (_, snap) {
                      final total = audio.player.duration?.inMilliseconds ?? 0;
                      final pos = snap.data?.inMilliseconds ?? 0;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : (pos / total).clamp(0, 1),
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(Palette.gold),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
