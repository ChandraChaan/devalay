import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Official devotional channels, from /config so new ones need no app update.
typedef VideoChannel = ({String id, String name, String nameTe, String nameHi});
typedef FeedVideo = ({String id, String title, DateTime published});

const _fallbackChannels = <VideoChannel>[
  (id: 'UCS2Y83GD-fc7qqgNW5uj41g', name: 'SVBC TTD', nameTe: 'ఎస్వీబీసీ (టీటీడీ)', nameHi: 'SVBC TTD'),
];

final videoChannelsProvider = FutureProvider<List<VideoChannel>>((ref) async {
  try {
    final list = (await ref.read(configProvider.future))['video_channels'] as List?;
    if (list == null || list.isEmpty) return _fallbackChannels;
    return [
      for (final c in list.cast<Map>())
        (
          id: '${c['id']}',
          name: '${c['name']}',
          nameTe: '${c['name_te'] ?? c['name']}',
          nameHi: '${c['name_hi'] ?? c['name']}',
        ),
    ];
  } catch (_) {
    return _fallbackChannels;
  }
});

/// A channel's public RSS feed: its latest 15 uploads, no API key needed.
final channelFeedProvider = FutureProvider.family<List<FeedVideo>, String>((ref, channelId) async {
  final res = await Dio().get<String>(
    'https://www.youtube.com/feeds/videos.xml',
    queryParameters: {'channel_id': channelId},
    options: Options(responseType: ResponseType.plain),
  );
  return parseYoutubeFeed(res.data ?? '');
});

List<FeedVideo> parseYoutubeFeed(String xml) {
  final out = <FeedVideo>[];
  for (final entry in RegExp(r'<entry>(.*?)</entry>', dotAll: true).allMatches(xml)) {
    final e = entry.group(1)!;
    final id = RegExp(r'<yt:videoId>([^<]+)</yt:videoId>').firstMatch(e)?.group(1);
    final title = RegExp(r'<title>([^<]*)</title>').firstMatch(e)?.group(1);
    final published = DateTime.tryParse(RegExp(r'<published>([^<]+)</published>').firstMatch(e)?.group(1) ?? '');
    if (id == null || title == null) continue;
    out.add((id: id, title: _unescape(title), published: published ?? DateTime(2000)));
  }
  return out;
}

String _unescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

/// Full-screen, swipe-up feed of temple videos, built for elders: one big video at a time,
/// large Telugu titles, no small buttons to hunt for. Plays in YouTube's embedded player.
class BhaktiVideosScreen extends ConsumerStatefulWidget {
  const BhaktiVideosScreen({super.key});
  @override
  ConsumerState<BhaktiVideosScreen> createState() => _BhaktiVideosScreenState();
}

class _BhaktiVideosScreenState extends ConsumerState<BhaktiVideosScreen> {
  String? _channel;
  int _page = 0;
  final _pager = PageController();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final channels = ref.watch(videoChannelsProvider).value ?? _fallbackChannels;
    final channel = channels.firstWhere((c) => c.id == _channel, orElse: () => channels.first);
    final feed = ref.watch(channelFeedProvider(channel.id));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr(ref, 'videos')),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/videos'),
            icon: const Icon(Icons.movie_rounded, color: Palette.gold),
            label: Text(tr(ref, 'movies'), style: const TextStyle(color: Palette.gold)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (channels.length > 1)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final c in channels)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t3(lang, c.name, c.nameHi, c.nameTe)),
                        selected: c.id == channel.id,
                        onSelected: (_) => setState(() {
                          _channel = c.id;
                          _page = 0;
                          if (_pager.hasClients) _pager.jumpToPage(0);
                        }),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: feed.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Palette.gold)),
              error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(channelFeedProvider(channel.id))),
              data: (videos) => videos.isEmpty
                  ? Center(
                      child: Text(
                        t3(lang, 'No videos right now.', 'अभी कोई वीडियो नहीं।', 'ప్రస్తుతం వీడియోలు లేవు.'),
                        style: const TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    )
                  : PageView.builder(
                      controller: _pager,
                      scrollDirection: Axis.vertical,
                      itemCount: videos.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _VideoPage(
                        key: ValueKey(videos[i].id),
                        video: videos[i],
                        active: i == _page,
                        channelName: t3(lang, channel.name, channel.nameHi, channel.nameTe),
                        hint: i + 1 < videos.length
                            ? t3(
                                lang,
                                'Swipe up for the next video',
                                'अगले वीडियो के लिए ऊपर खिसकाएँ',
                                'తర్వాతి వీడియో కోసం పైకి జరపండి',
                              )
                            : null,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    super.key,
    required this.video,
    required this.active,
    required this.channelName,
    required this.hint,
  });
  final FeedVideo video;
  final bool active;
  final String channelName;
  final String? hint;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    // Only the visible page holds a player (each is a WebView), so memory stays low.
    if (widget.active && _controller == null) _start();
    if (!widget.active && _controller != null) _stop();
  }

  void _start() {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true, interfaceLanguage: 'te'),
    );
  }

  void _stop() {
    _controller?.close();
    _controller = null;
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumb = 'https://i.ytimg.com/vi/${widget.video.id}/hqdefault.jpg';
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _controller != null
                ? YoutubePlayer(controller: _controller!, aspectRatio: 16 / 9, enableFullScreenOnVerticalDrag: false)
                : AspectRatio(aspectRatio: 16 / 9, child: NetImage(thumb)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            widget.video.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
        Text(widget.channelName, style: const TextStyle(color: Colors.white60, fontSize: 15)),
        const SizedBox(height: 16),
        if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                const Icon(Icons.keyboard_double_arrow_up_rounded, color: Palette.gold, size: 32),
                Text(widget.hint!, style: const TextStyle(color: Palette.gold, fontSize: 15)),
              ],
            ),
          ),
      ],
    );
  }
}
