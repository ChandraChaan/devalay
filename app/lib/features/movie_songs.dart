import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import 'bhakti_videos.dart' show FeedVideo, channelFeedProvider, parseYoutubeFeed;

/// Devotional film songs, kept apart from Devalay's own licensed audio. Film songs belong to their
/// labels, so the app never hosts them: it plays the labels' own uploads (Aditya Music, Mango Music,
/// T-Series, Rajshri, Saregama) in YouTube's embedded player. The list comes from /config
/// (`movie_albums`), so albums can be added without an app update.
typedef MovieAlbum = ({
  String id,
  bool playlist,
  String thumb,
  String en,
  String te,
  String hi,
  int year,
  String label,
  String deity,
});

const fallbackMovieAlbums = <MovieAlbum>[
  (
    id: 'ee6ECZ8lBW0',
    playlist: false,
    thumb: 'ee6ECZ8lBW0',
    en: 'Annamayya',
    te: 'అన్నమయ్య',
    hi: 'अन्नमय्या',
    year: 1997,
    label: 'Rajshri Telugu',
    deity: 'venkateswara',
  ),
  (
    id: 'PL82bFVRc-OqruZgQrQwz1WQqsmOjjO2Zf',
    playlist: true,
    thumb: 'ee6ECZ8lBW0',
    en: 'Annamayya keerthanas',
    te: 'అన్నమయ్య కీర్తనలు',
    hi: 'अन्नमय्या कीर्तन',
    year: 1997,
    label: 'T-Series Bhakti Sagar Telugu',
    deity: 'venkateswara',
  ),
  (
    id: 'YD4xclAqi5I',
    playlist: false,
    thumb: 'YD4xclAqi5I',
    en: 'Sri Ramadasu',
    te: 'శ్రీ రామదాసు',
    hi: 'श्री रामदासु',
    year: 2006,
    label: 'Aditya Music',
    deity: 'rama',
  ),
  (
    id: 'PL55V3LFPiH7w5AllZn63NSXnKWJj9GfE0',
    playlist: true,
    thumb: 'YD4xclAqi5I',
    en: 'Sri Ramadasu, song by song',
    te: 'శ్రీ రామదాసు పాటలు',
    hi: 'श्री रामदासु गीत',
    year: 2006,
    label: 'Aditya Bhakthi',
    deity: 'rama',
  ),
  (
    id: 'Xi-yG8okL9c',
    playlist: false,
    thumb: 'Xi-yG8okL9c',
    en: 'Om Namo Venkatesaya',
    te: 'ఓం నమో వేంకటేశాయ',
    hi: 'ओम नमो वेंकटेशाय',
    year: 2017,
    label: 'T-Series Telugu',
    deity: 'venkateswara',
  ),
  (
    id: 'E0WLI-t6d98',
    playlist: false,
    thumb: 'E0WLI-t6d98',
    en: 'Shirdi Sai',
    te: 'షిరిడి సాయి',
    hi: 'शिरडी साई',
    year: 2012,
    label: 'Mango Music',
    deity: 'general',
  ),
  (
    id: 'PL5HDCGtq1uZsohL61yCZHDsMMC1RsD1bq',
    playlist: true,
    thumb: 'H_hXTzigXDA',
    en: 'Sri Rama Rajyam',
    te: 'శ్రీ రామ రాజ్యం',
    hi: 'श्री राम राज्यम',
    year: 2011,
    label: 'Mango Music',
    deity: 'rama',
  ),
  (
    id: 'CyWOuZQCz-Q',
    playlist: false,
    thumb: 'CyWOuZQCz-Q',
    en: 'Pandurangadu',
    te: 'పాండురంగడు',
    hi: 'पांडुरंगडु',
    year: 2008,
    label: 'Aditya Music',
    deity: 'krishna',
  ),
  (
    id: 'UsNdWrXfl1w',
    playlist: false,
    thumb: 'UsNdWrXfl1w',
    en: 'Sri Manjunatha',
    te: 'శ్రీ మంజునాథ',
    hi: 'श्री मंजुनाथ',
    year: 2001,
    label: 'Saregama Telugu',
    deity: 'shiva',
  ),
];

/// Official devotional channels for the "New songs" tab.
const _devotionalChannels = [
  ('UCZQ3VR0OxbRVVy5uzfGomUg', 'Aditya Bhakthi'),
  ('UCjA7qIB2IetzeolMd_Hwa0w', 'T-Series Bhakti Sagar Telugu'),
];

/// Albums from /config when it has them, else the built-in list.
final movieAlbumsProvider = FutureProvider<List<MovieAlbum>>((ref) async {
  try {
    final list = (await ref.read(configProvider.future))['movie_albums'] as List?;
    if (list == null || list.isEmpty) return fallbackMovieAlbums;
    return [for (final m in list.cast<Map>()) parseMovieAlbum(m)];
  } catch (_) {
    return fallbackMovieAlbums;
  }
});

MovieAlbum parseMovieAlbum(Map m) => (
  id: '${m['id']}',
  playlist: m['playlist'] == true,
  thumb: '${m['thumb'] ?? m['id']}',
  en: '${m['title'] ?? ''}',
  te: '${m['title_te'] ?? m['title'] ?? ''}',
  hi: '${m['title_hi'] ?? m['title'] ?? ''}',
  year: (m['year'] as num?)?.toInt() ?? 0,
  label: '${m['label'] ?? ''}',
  deity: '${m['deity'] ?? 'general'}',
);

final playlistFeedProvider = FutureProvider.family<List<FeedVideo>, String>((ref, playlistId) async {
  final res = await Dio().get<String>(
    'https://www.youtube.com/feeds/videos.xml',
    queryParameters: {'playlist_id': playlistId},
    options: Options(responseType: ResponseType.plain),
  );
  return parseYoutubeFeed(res.data ?? '');
});

String _thumb(String videoId) => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

class MovieSongsScreen extends ConsumerWidget {
  const MovieSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final albums = ref.watch(movieAlbumsProvider).value ?? fallbackMovieAlbums;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t3(lang, 'Movie bhakti songs', 'फ़िल्मी भक्ति गीत', 'సినిమా భక్తి పాటలు')),
          bottom: TabBar(
            tabs: [
              Tab(text: t3(lang, 'Movie albums', 'फ़िल्म एल्बम', 'సినిమా ఆల్బమ్‌లు')),
              Tab(text: t3(lang, 'New songs', 'नए गीत', 'కొత్త పాటలు')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GridView.builder(
              padding: const EdgeInsets.all(12).withSystemInsets(context),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemCount: albums.length + 1,
              itemBuilder: (_, i) {
                if (i == albums.length) return _Note(lang: lang);
                final a = albums[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Usage.record('movie_album', item: a.id);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => MovieAlbumScreen(album: a)));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              NetImage(_thumb(a.thumb)),
                              const Center(
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                          child: Text(
                            t3(lang, a.en, a.hi, a.te),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${a.year > 0 ? '${a.year} · ' : ''}${a.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const _NewSongs(),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.lang});
  final String lang;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Center(
      child: Text(
        t3(
          lang,
          'Played from the music labels\' official YouTube channels. Needs internet.',
          'संगीत कंपनियों के आधिकारिक YouTube चैनलों से चलता है। इंटरनेट चाहिए।',
          'సంగీత సంస్థల అధికారిక YouTube ఛానెళ్ల నుండి ప్లే అవుతుంది. ఇంటర్నెట్ కావాలి.',
        ),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}

class _NewSongs extends ConsumerStatefulWidget {
  const _NewSongs();
  @override
  ConsumerState<_NewSongs> createState() => _NewSongsState();
}

class _NewSongsState extends ConsumerState<_NewSongs> {
  int _channel = 0;
  @override
  Widget build(BuildContext context) {
    final (id, name) = _devotionalChannels[_channel];
    final feed = ref.watch(channelFeedProvider(id));
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final (i, c) in _devotionalChannels.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.$2),
                    selected: i == _channel,
                    onSelected: (_) => setState(() => _channel = i),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: feed.when(
            loading: () => const LoadingList(),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(channelFeedProvider(id))),
            data: (videos) => _VideoList(
              videos: videos,
              onTap: (i) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MovieAlbumScreen(
                    album: (
                      id: videos[i].id,
                      playlist: false,
                      thumb: videos[i].id,
                      en: videos[i].title,
                      te: videos[i].title,
                      hi: videos[i].title,
                      year: 0,
                      label: name,
                      deity: 'general',
                    ),
                    queue: videos,
                    start: i,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoList extends StatelessWidget {
  const _VideoList({required this.videos, required this.onTap, this.selected});
  final List<FeedVideo> videos;
  final ValueChanged<int> onTap;
  final int? selected;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.only(bottom: 16).withSystemInsets(context),
    itemCount: videos.length,
    itemBuilder: (_, i) => ListTile(
      selected: i == selected,
      leading: SizedBox(width: 96, height: 54, child: NetImage(_thumb(videos[i].id), radius: 8)),
      title: Text(videos[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Icon(i == selected ? Icons.equalizer_rounded : Icons.play_arrow_rounded),
      onTap: () => onTap(i),
    ),
  );
}

/// One album: the label's video plays on top; a playlist lists its songs below.
class MovieAlbumScreen extends ConsumerStatefulWidget {
  const MovieAlbumScreen({super.key, required this.album, this.queue, this.start = 0});
  final MovieAlbum album;

  /// Songs to play one after another (a channel's latest uploads).
  final List<FeedVideo>? queue;
  final int start;
  @override
  ConsumerState<MovieAlbumScreen> createState() => _MovieAlbumScreenState();
}

class _MovieAlbumScreenState extends ConsumerState<MovieAlbumScreen> {
  YoutubePlayerController? _player;
  late int _index = widget.start;

  @override
  void initState() {
    super.initState();
    if (!widget.album.playlist) _play(widget.queue?[_index].id ?? widget.album.id);
  }

  void _play(String videoId) {
    if (_player == null) {
      _player = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true),
      );
    } else {
      _player!.loadVideoById(videoId: videoId);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _player?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final a = widget.album;
    final feed = a.playlist ? ref.watch(playlistFeedProvider(a.id)) : null;
    final songs = widget.queue ?? feed?.value;
    if (a.playlist && _player == null && songs != null && songs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted && _player == null ? _play(songs[_index].id) : null);
    }
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, a.en, a.hi, a.te), maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _player == null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      NetImage(_thumb(a.thumb)),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  )
                : YoutubePlayer(controller: _player!),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: Palette.marigold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t3(
                      lang,
                      'Official upload: ${a.label}',
                      'आधिकारिक अपलोड: ${a.label}',
                      'అధికారిక అప్‌లోడ్: ${a.label}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (songs != null)
            Expanded(
              child: _VideoList(
                videos: songs,
                selected: _index,
                onTap: (i) {
                  setState(() => _index = i);
                  _play(songs[i].id);
                },
              ),
            )
          else if (feed?.isLoading ?? false)
            const Expanded(child: LoadingList())
          else if (feed?.hasError ?? false)
            Expanded(
              child: ErrorRetry(error: feed!.error!, onRetry: () => ref.invalidate(playlistFeedProvider(a.id))),
            ),
        ],
      ),
    );
  }
}
