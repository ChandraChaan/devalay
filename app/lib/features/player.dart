import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../core/audio.dart';
import '../core/auth.dart';
import '../core/config.dart';
import '../core/downloads.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider).value;
    final audio = ref.read(audioProvider);
    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.music_note_rounded, title: 'Nothing playing'),
      );
    }
    final playing = ref.watch(playingProvider).value ?? false;
    return Scaffold(
      backgroundColor: Palette.night,
      body: Stack(
        fit: StackFit.expand,
        children: [
          NetImage(track.artworkUrl),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                    ),
                    const Spacer(),
                    _SleepButton(audio: audio),
                    IconButton(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              '🙏 ${track.title} — listen on Devalay\n${track.sourceUrl.isNotEmpty ? track.sourceUrl : AppConfig.sourceUrl}',
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const Spacer(),
                Hero(
                  tag: 'player-card',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Mandala(size: 340, color: Palette.gold, opacity: playing ? 0.35 : 0.15, spin: playing),
                      AnimatedScale(
                        scale: playing ? 1 : 0.9,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.gold, width: 4),
                            boxShadow: [
                              BoxShadow(color: Palette.saffron.withValues(alpha: playing ? 0.6 : 0.2), blurRadius: 40),
                            ],
                          ),
                          child: ClipOval(child: NetImage(track.artworkUrl)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(
                        pick(ref, track.title, track.titleHi),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Attribution(track, light: true),
                    ],
                  ),
                ),
                _SeekBar(player: audio.player),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<LoopMode>(
                      stream: audio.player.loopModeStream,
                      builder: (_, s) => IconButton(
                        onPressed: audio.cycleLoop,
                        icon: Icon(
                          s.data == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                          color: s.data == LoopMode.off || s.data == null ? Colors.white54 : Palette.gold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: audio.player.seekToPrevious,
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
                    ),
                    GestureDetector(
                      onTap: audio.toggle,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                        child: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Palette.maroon,
                          size: 44,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: audio.player.seekToNext,
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
                    ),
                    FavoriteButton(
                      color: Colors.white54,
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DownloadButton(track: track),
                    if (track.textSlug != null)
                      TextButton.icon(
                        onPressed: () => context.push('/text/${track.textSlug}'),
                        icon: const Icon(Icons.lyrics_outlined, color: Colors.white),
                        label: const Text('Lyrics', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.player});
  final AudioPlayer player;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final total = player.duration ?? Duration.zero;
        final pos = snap.data ?? Duration.zero;
        final max = total.inMilliseconds.toDouble();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Palette.gold,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: max == 0 ? 0 : pos.inMilliseconds.clamp(0, max).toDouble(),
                  max: max == 0 ? 1 : max,
                  onChanged: max == 0 ? null : (v) => player.seek(Duration(milliseconds: v.round())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(pos), style: const TextStyle(color: Colors.white70)),
                    Text(formatDuration(total), style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SleepButton extends StatefulWidget {
  const _SleepButton({required this.audio});
  final AudioController audio;
  @override
  State<_SleepButton> createState() => _SleepButtonState();
}

class _SleepButtonState extends State<_SleepButton> {
  @override
  Widget build(BuildContext context) {
    final active = widget.audio.sleepAt != null && widget.audio.sleepAt!.isAfter(DateTime.now());
    return PopupMenuButton<int>(
      tooltip: 'Sleep timer',
      icon: Icon(Icons.bedtime_outlined, color: active ? Palette.gold : Colors.white),
      onSelected: (m) {
        widget.audio.setSleepTimer(m == 0 ? null : Duration(minutes: m));
        setState(() {});
        toast(context, m == 0 ? 'Sleep timer off' : 'Playback will stop in $m minutes');
      },
      itemBuilder: (_) => [
        for (final m in [10, 20, 30, 60]) PopupMenuItem(value: m, child: Text('$m minutes')),
        const PopupMenuItem(value: 0, child: Text('Off')),
      ],
    );
  }
}

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({required this.track});
  final Track track;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(downloadsProvider);
    final store = ref.read(downloadsProvider.notifier);
    final progress = store.progress(track.id);
    final done = store.isDownloaded(track.id);
    if (progress != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(value: progress, color: Palette.gold, strokeWidth: 3),
        ),
      );
    }
    return TextButton.icon(
      onPressed: () async {
        if (done) {
          await store.remove(track.id);
          return;
        }
        try {
          await store.download(
            track,
            premium: ref.read(authProvider).isPremium,
            freeLimit: AppConfig.freeDownloadLimit,
          );
          if (context.mounted) toast(context, 'Saved for offline listening');
        } on DownloadLimitReached {
          if (context.mounted) {
            toast(context, 'Free plan keeps ${AppConfig.freeDownloadLimit} downloads. Remove one or go Premium.');
          }
        } catch (_) {
          if (context.mounted) toast(context, tr(ref, 'error'));
        }
      },
      icon: Icon(done ? Icons.download_done_rounded : Icons.download_rounded, color: Colors.white),
      label: Text(done ? 'Downloaded' : 'Download', style: const TextStyle(color: Colors.white)),
    );
  }
}
