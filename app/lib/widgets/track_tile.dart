import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio.dart';
import '../core/downloads.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'common.dart';

class TrackTile extends ConsumerWidget {
  const TrackTile({super.key, required this.track, required this.queue, required this.index});
  final Track track;
  final List<Track> queue;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackProvider).value;
    final playing = ref.watch(playingProvider).value ?? false;
    final isCurrent = current?.id == track.id;
    final downloaded = ref.watch(downloadsProvider.select((m) => m.containsKey(track.id)));
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            isCurrent ? ref.read(audioProvider).toggle() : ref.read(audioProvider).playQueue(queue, index: index),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: 58, height: 58, child: NetImage(track.artworkUrl, radius: 14)),
                  if (isCurrent)
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(14)),
                      child: Icon(playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.label(uiLang(ref)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isCurrent ? scheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _KindChip(track.kind),
                        if (track.durationSec > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatDuration(Duration(seconds: track.durationSec)),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (downloaded) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.download_done_rounded, size: 16, color: scheme.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              FavoriteButton(
                item: FavoriteItem(
                  type: 'track',
                  id: '${track.id}',
                  title: track.title,
                  subtitle: track.kind,
                  image: track.artworkUrl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends ConsumerWidget {
  const _KindChip(this.kind);
  final String kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Palette.marigold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tr(ref, kind),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.saffron),
      ),
    );
  }
}
