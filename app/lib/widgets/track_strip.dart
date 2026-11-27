import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/names.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import 'common.dart';

/// A horizontal row of big song cards. Tapping one plays the row as a queue; [from] names the row
/// in the usage log.
class TrackStrip extends ConsumerWidget {
  const TrackStrip({super.key, required this.tracks, required this.from});
  final List<Track> tracks;
  final String from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackProvider).value;
    final playing = ref.watch(playingProvider).value ?? false;
    final lang = uiLang(ref);
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final t = tracks[i];
          final isCurrent = current?.id == t.id;
          return Semantics(
            button: true,
            label: t.label(lang),
            child: GestureDetector(
              onTap: () => isCurrent
                  ? ref.read(audioProvider).toggle()
                  : ref.read(audioProvider).playQueue(tracks, index: i, from: from),
              child: SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: t.artworkUrl.isEmpty ? _ArtFallback(kind: t.kind) : NetImage(t.artworkUrl, radius: 20),
                        ),
                        if (t.durationSec > 0)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                formatDuration(Duration(seconds: t.durationSec)),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isCurrent && playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Palette.saffron,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.label(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.2,
                        color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tracks without a painting (drones, bells) get a warm gradient and an emoji instead of a grey box.
class _ArtFallback extends StatelessWidget {
  const _ArtFallback({required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Palette.saffron, Palette.maroon],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(switch (kind) {
      'ringtone' => '🔔',
      'ambient' => '🕉️',
      'dhun' => '🪈',
      'aarti' => '🪔',
      _ => '🎶',
    }, style: const TextStyle(fontSize: 52)),
  );
}

/// A titled [TrackStrip] for an async list: nothing while loading or when empty, so a slow or
/// offline catalogue never leaves an empty header behind.
class TrackRow extends ConsumerWidget {
  const TrackRow({
    super.key,
    required this.title,
    required this.tracks,
    required this.from,
    this.action,
    this.onAction,
  });
  final String title;
  final AsyncValue<List<Track>> tracks;
  final String from;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = tracks.value ?? const <Track>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title, action: action, onAction: onAction),
        TrackStrip(tracks: list, from: from),
      ],
    );
  }
}

/// "Monday: Shiva's songs". Each weekday belongs to a deity; Telugu homes keep Saturday for
/// Venkateswara, so Telugu users get that map and everyone else gets the server's deity of the day.
class TodaysSongs extends ConsumerWidget {
  const TodaysSongs({super.key, this.serverDeity, required this.from});
  final Deity? serverDeity;
  final String from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider).language;
    final weekday = DateTime.now().weekday - 1;
    final slug = lang == 'te' ? teluguWeekdayDeity[weekday] : (serverDeity?.slug ?? teluguWeekdayDeity[weekday]);
    final deities = ref.watch(deitiesProvider).value ?? const <Deity>[];
    final deity = deities.where((d) => d.slug == slug).firstOrNull ?? serverDeity;
    final tracks = ref.watch(tracksProvider((kind: null, deity: slug))).value ?? const <Track>[];
    if (tracks.isEmpty || deity == null) return const SizedBox.shrink();
    final day = fmtDate(lang, 'EEEE', DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          t3(
            lang,
            '$day · ${deity.label(lang)} songs',
            '$day · ${deity.label(lang)} के भजन',
            '$day · ${deity.label(lang)} పాటలు',
          ),
          action: t3(lang, 'Play all', 'सब चलाएँ', 'అన్నీ ప్లే'),
          onAction: () => ref.read(audioProvider).playQueue(tracks, index: 0, from: from),
        ),
        TrackStrip(tracks: tracks, from: from),
      ],
    );
  }
}
