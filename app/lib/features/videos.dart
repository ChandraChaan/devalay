import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../core/audio.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../widgets/common.dart';

class VideosScreen extends ConsumerWidget {
  const VideosScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(videosProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'movies'))),
      body: videos.when(
        loading: () => const LoadingList(height: 200),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(videosProvider)),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l3(
                ref,
                'Public-domain mythological films by Dadasaheb Phalke, the father of Indian cinema.',
                'भारतीय सिनेमा के जनक दादासाहेब फाल्के की सार्वजनिक-डोमेन पौराणिक फ़िल्में।',
                'భారతీయ సినిమా పితామహుడు దాదాసాహెబ్ ఫాల్కే తీసిన పబ్లిక్-డొమైన్ పౌరాణిక చిత్రాలు.',
              ),
            ),
            const SizedBox(height: 12),
            for (final v in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/video', extra: v),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              NetImage(v.thumbnailUrl, alignment: Alignment.center),
                              const Center(
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  color: Colors.black54,
                                  child: Text(
                                    formatDuration(Duration(seconds: v.durationSec)),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(v.description),
                              Attribution(v),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.video});
  final Video video;
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
  Object? _error;

  @override
  void initState() {
    super.initState();
    ref.read(audioProvider).player.pause();
    _c
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
          _c.play();
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e);
        });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(widget.video.title, style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error != null
                  ? const Text(
                      'This film could not be played. Check your connection.',
                      style: TextStyle(color: Colors.white),
                    )
                  : !ready
                  ? const CircularProgressIndicator()
                  : GestureDetector(
                      onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(),
                      child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
                    ),
            ),
          ),
          if (ready) ...[
            VideoProgressIndicator(_c, allowScrubbing: true, padding: const EdgeInsets.all(16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _c.seekTo(_c.value.position - const Duration(seconds: 10)),
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                ),
                IconButton(
                  iconSize: 48,
                  onPressed: () => _c.value.isPlaying ? _c.pause() : _c.play(),
                  icon: Icon(
                    _c.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => _c.seekTo(_c.value.position + const Duration(seconds: 10)),
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                ),
              ],
            ),
            Text(
              '${formatDuration(_c.value.position)} / ${formatDuration(_c.value.duration)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          Padding(padding: const EdgeInsets.all(16), child: Attribution(widget.video, light: true)),
        ],
      ),
    );
  }
}
