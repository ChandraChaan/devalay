import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../core/audio.dart';
import '../core/auth.dart';
import '../core/config.dart';
import '../core/downloads.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/script.dart';
import '../core/theme.dart';
import '../core/sharing.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  /// Lyrics in place of the artwork, following the song.
  bool _lyrics = false;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentTrackProvider).value;
    final audio = ref.read(audioProvider);
    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.music_note_rounded,
          title: t3(appLang, 'Nothing playing', 'कुछ नहीं चल रहा', 'ఏదీ ప్లే అవ్వడం లేదు'),
        ),
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
                    _SpeedButton(player: audio.player),
                    _SleepButton(audio: audio),
                    IconButton(
                      onPressed: () =>
                          shareContent('🙏 ${track.title} — listen on Devalay\n${playLink('song')}', what: 'song'),
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                    ),
                  ],
                ),
                if (_lyrics && track.textSlug != null)
                  Expanded(
                    flex: 6,
                    child: _LyricsPanel(slug: track.textSlug!, player: audio.player),
                  )
                else ...[
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
                                BoxShadow(
                                  color: Palette.saffron.withValues(alpha: playing ? 0.6 : 0.2),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                            child: ClipOval(child: NetImage(track.artworkUrl)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(
                        track.label(uiLang(ref)),
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
                        onPressed: () => setState(() => _lyrics = !_lyrics),
                        icon: Icon(
                          _lyrics ? Icons.album_rounded : Icons.lyrics_outlined,
                          color: _lyrics ? Palette.gold : Colors.white,
                        ),
                        label: Text(
                          _lyrics
                              ? t3(appLang, 'Artwork', 'चित्र', 'చిత్రం')
                              : t3(appLang, 'Lyrics', 'बोल', 'సాహిత్యం'),
                          style: const TextStyle(color: Colors.white),
                        ),
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
      tooltip: t3(appLang, 'Sleep timer', 'स्लीप टाइमर', 'స్లీప్ టైమర్'),
      icon: Icon(Icons.bedtime_outlined, color: active ? Palette.gold : Colors.white),
      onSelected: (m) {
        widget.audio.setSleepTimer(m == 0 ? null : Duration(minutes: m));
        setState(() {});
        toast(context, m == 0 ? 'Sleep timer off' : 'Playback will stop in $m minutes');
      },
      itemBuilder: (_) => [
        for (final m in [10, 20, 30, 60]) PopupMenuItem(value: m, child: Text('$m minutes')),
        PopupMenuItem(value: 0, child: Text(t3(appLang, 'Off', 'बंद', 'ఆఫ్'))),
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
          if (context.mounted) {
            toast(
              context,
              t3(
                appLang,
                'Saved for offline listening',
                'ऑफ़लाइन सुनने के लिए सहेजा गया',
                'ఆఫ్‌లైన్‌లో వినడానికి సేవ్ అయింది',
              ),
            );
          }
        } on DownloadLimitReached {
          if (context.mounted) {
            toast(
              context,
              t3(
                appLang,
                'Free plan keeps ${AppConfig.freeDownloadLimit} downloads. Remove one or go Premium.',
                'मुफ़्त प्लान में ${AppConfig.freeDownloadLimit} डाउनलोड रहते हैं। एक हटाएँ या प्रीमियम लें।',
                'ఉచిత ప్లాన్‌లో ${AppConfig.freeDownloadLimit} డౌన్‌లోడ్‌లు మాత్రమే. ఒకటి తీసేయండి లేదా ప్రీమియం తీసుకోండి.',
              ),
            );
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

/// Playback speed for chants and stotrams: 0.75×, 1×, 1.25×, 1.5×.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.player});
  final AudioPlayer player;
  static const _speeds = [1.0, 1.25, 1.5, 0.75];

  @override
  Widget build(BuildContext context) => StreamBuilder<double>(
    stream: player.speedStream,
    builder: (_, s) {
      final speed = s.data ?? 1.0;
      return TextButton(
        onPressed: () {
          final i = _speeds.indexWhere((v) => (v - speed).abs() < 0.01);
          player.setSpeed(_speeds[(i + 1) % _speeds.length]);
        },
        child: Text(
          '${speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : speed.toString()}×',
          style: TextStyle(color: speed == 1.0 ? Colors.white : Palette.gold, fontWeight: FontWeight.w800),
        ),
      );
    },
  );
}

/// The song's words in the reader's script, the current line lit and kept in view as the song plays. The
/// line is estimated from the playback position (most recordings sing the text once, start to end).
class _LyricsPanel extends ConsumerStatefulWidget {
  const _LyricsPanel({required this.slug, required this.player});
  final String slug;
  final AudioPlayer player;
  @override
  ConsumerState<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<_LyricsPanel> {
  final _scroll = ScrollController();
  final _keys = <GlobalKey>[];
  int _current = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow(int line) {
    if (line == _current || line < 0 || line >= _keys.length) return;
    _current = line;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[line].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.4,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final text = ref.watch(textProvider(widget.slug));
    return text.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (_, _) => Center(
        child: Text(
          t3(
            lang,
            'Lyrics need the internet once.',
            'बोल के लिए एक बार इंटरनेट चाहिए।',
            'సాహిత్యం కోసం ఒకసారి ఇంటర్నెట్ కావాలి.',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      data: (t) {
        final body = switch (lang) {
          'hi' || 'mr' => t.body,
          'en' => t.transliteration.isEmpty ? t.body : t.transliteration,
          _ => toIndicScript(lang, t.body),
        };
        final lines = body.split('\n');
        final sung = [
          for (var i = 0; i < lines.length; i++)
            if (lines[i].trim().isNotEmpty) i,
        ];
        while (_keys.length < lines.length) {
          _keys.add(GlobalKey());
        }
        return StreamBuilder<Duration>(
          stream: widget.player.positionStream,
          builder: (_, snap) {
            final total = widget.player.duration?.inMilliseconds ?? 0;
            final pos = snap.data?.inMilliseconds ?? 0;
            // Skip a short instrumental opening: the words usually start a few seconds in.
            final f = total <= 0 ? 0.0 : ((pos / total - 0.04) / 0.94).clamp(0.0, 0.9999);
            final active = sung.isEmpty ? -1 : sung[(f * sung.length).floor()];
            _follow(active);
            return ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.12, 0.88, 1],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                itemCount: lines.length,
                itemBuilder: (_, i) {
                  final on = i == active;
                  return AnimatedDefaultTextStyle(
                    key: _keys[i],
                    duration: const Duration(milliseconds: 300),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: scriptureFont,
                      fontFamilyFallback: scriptureFontFallback,
                      color: on ? Palette.gold : Colors.white.withValues(alpha: 0.62),
                      fontSize: on ? 22 : 18,
                      height: 1.6,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(lines[i].isEmpty ? ' ' : lines[i], textAlign: TextAlign.center),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
