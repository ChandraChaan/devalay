import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n.dart';
import '../core/listening.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import '../widgets/track_strip.dart';
import '../widgets/track_tile.dart';

const _kinds = [null, 'aarti', 'mantra', 'bhajan', 'dhun', 'ambient'];

/// The Listen tab: big type tiles, mantra chanting, then rows people actually play from
/// (continue, most played, today's deity, Telugu keerthanalu, ringtones).
class ListenScreen extends ConsumerWidget {
  const ListenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final all = ref.watch(allTracksProvider);
    final telugu = TrackRow(
      title: t3(lang, 'Telugu keerthanalu', 'तेलुगु कीर्तन', 'తెలుగు కీర్తనలు'),
      tracks: ref.watch(teluguSongsProvider),
      from: 'telugu',
    );
    final ringtones = TrackRow(
      title: tr(ref, 'ringtones'),
      tracks: ref.watch(ringtoneTracksProvider),
      from: 'ringtone_row',
      action: t3(lang, 'Set ringtone', 'रिंगटोन लगाएँ', 'రింగ్‌టోన్ పెట్టండి'),
      onAction: () => context.push('/ringtones'),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'listen')),
        actions: [
          IconButton(
            tooltip: tr(ref, 'downloads'),
            onPressed: () => context.push('/downloads'),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tracksProvider((kind: null, deity: null)).future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120).withSystemInsets(context),
          children: [
            const _KindTiles(),
            const _ChantCard(),
            if (all.hasError && !all.hasValue)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorRetry(
                  error: all.error!,
                  onRetry: () => ref.invalidate(tracksProvider((kind: null, deity: null))),
                ),
              )
            else if (all.isLoading && !all.hasValue)
              const Padding(padding: EdgeInsets.all(16), child: SkeletonBox(height: 200)),
            TrackRow(
              title: t3(lang, 'Continue listening', 'सुनना जारी रखें', 'వినడం కొనసాగించండి'),
              tracks: ref.watch(recentTracksProvider),
              from: 'continue',
            ),
            TrackRow(
              title: t3(lang, 'Most played', 'सबसे ज़्यादा सुने गए', 'ఎక్కువ మంది వింటున్నవి'),
              tracks: ref.watch(popularTracksProvider),
              from: 'popular',
              action: tr(ref, 'see_all'),
              onAction: () => _browse(context, null),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GradientCard(
                colors: const [Color(0xFF311B92), Color(0xFFC2185B)],
                padding: 14,
                onTap: () {
                  Usage.record('listen_category', item: 'movie');
                  context.push('/movie-songs');
                },
                child: Row(
                  children: [
                    const Text('🎬', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t3(lang, 'Movie bhakti songs', 'फ़िल्मी भक्ति गीत', 'సినిమా భక్తి పాటలు'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          Text(
                            t3(
                              lang,
                              'Annamayya, Sri Ramadasu, Shirdi Sai and more, from the official labels',
                              'अन्नमय्या, श्री रामदासु, शिरडी साई और भी, आधिकारिक चैनलों से',
                              'అన్నమయ్య, శ్రీ రామదాసు, షిరిడి సాయి ఇంకా, అధికారిక ఛానెళ్ల నుండి',
                            ),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
            const TodaysSongs(from: 'today'),
            if (lang == 'te') ...[telugu, ringtones] else ...[ringtones, telugu],
          ],
        ),
      ),
    );
  }
}

void _browse(BuildContext context, String? kind) {
  Usage.record('listen_category', item: kind ?? 'all');
  context.push(switch (kind) {
    null => '/songs',
    'ringtones' => '/ringtones',
    'favorites' => '/favorites',
    'ambient' => '/meditation',
    _ => '/songs?kind=$kind',
  });
}

/// Six big tiles, three to a row, so the type of song is one tap away (and easy to hit).
class _KindTiles extends ConsumerWidget {
  const _KindTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = [
      ('🪔', 'aarti', Palette.sunrise),
      ('🕉️', 'mantra', Palette.dusk),
      ('🎶', 'bhajan', const [Color(0xFFAD1457), Color(0xFFE65100)]),
      ('🔔', 'ringtones', Palette.tulsi),
      ('🧘', 'ambient', Palette.sky),
      ('❤️', 'favorites', const [Color(0xFFC62828), Color(0xFFEF5350)]),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: [
          for (final (emoji, key, colors) in tiles)
            GradientCard(
              colors: colors,
              padding: 8,
              radius: 20,
              onTap: () => _browse(context, key),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(height: 4),
                  TileLabel(
                    tr(ref, key),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, height: 1.1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Chant with the mantra": opens the chant screen (11, 21 or 108 repetitions with a counter).
class _ChantCard extends ConsumerWidget {
  const _ChantCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GradientCard(
        colors: const [Color(0xFF4E342E), Color(0xFFBF360C)],
        onTap: () => context.push('/chant'),
        child: Row(
          children: [
            const Text('📿', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t3(lang, 'Chant with the mantra', 'मंत्र के साथ जाप करें', 'మంత్రంతో జపం చేయండి'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t3(
                      lang,
                      'Gayatri, Om Namah Shivaya and more: 11, 21 or 108 times, with a counter',
                      'गायत्री, ॐ नमः शिवाय और अन्य: 11, 21 या 108 बार, गिनती के साथ',
                      'గాయత్రి, ఓం నమః శివాయ మొదలైనవి: 11, 21 లేదా 108 సార్లు, లెక్కతో',
                    ),
                    style: const TextStyle(color: Colors.white70, height: 1.25),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Every song by type and deity, in tabs: "See all" from the Listen page's tiles.
class ListenBrowseScreen extends ConsumerStatefulWidget {
  const ListenBrowseScreen({super.key, this.kind});

  /// The tab to open on (aarti, mantra, bhajan, dhun, ambient); null opens "All".
  final String? kind;
  @override
  ConsumerState<ListenBrowseScreen> createState() => _ListenBrowseScreenState();
}

class _ListenBrowseScreenState extends ConsumerState<ListenBrowseScreen> {
  String? _deity;

  @override
  Widget build(BuildContext context) {
    final deities = ref.watch(deitiesProvider).value ?? const <Deity>[];
    final lang = ref.watch(prefsProvider).language;
    return DefaultTabController(
      length: _kinds.length,
      initialIndex: _kinds.indexOf(widget.kind).clamp(0, _kinds.length - 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(ref, 'listen')),
          actions: [
            IconButton(
              tooltip: tr(ref, 'downloads'),
              onPressed: () => context.push('/downloads'),
              icon: const Icon(Icons.download_for_offline_outlined),
            ),
            IconButton(
              tooltip: tr(ref, 'ringtones'),
              onPressed: () => context.push('/ringtones'),
              icon: const Icon(Icons.notifications_active_outlined),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(104),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tr(ref, 'all')),
                          selected: _deity == null,
                          onSelected: (_) => setState(() => _deity = null),
                        ),
                      ),
                      for (final d in deities.where((d) => d.slug != 'general'))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundImage: d.imageUrl.isEmpty ? null : NetworkImageProvider(d.imageUrl),
                            ),
                            label: Text(d.label(lang)),
                            selected: _deity == d.slug,
                            onSelected: (_) => setState(() => _deity = _deity == d.slug ? null : d.slug),
                          ),
                        ),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final k in _kinds) Tab(text: tr(ref, k ?? 'all'))],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            for (final k in _kinds)
              _TrackList(query: (kind: k ?? 'aarti,mantra,bhajan,chalisa,dhun,ambient', deity: _deity)),
          ],
        ),
      ),
    );
  }
}

class _TrackList extends ConsumerWidget {
  const _TrackList({required this.query});
  final TrackQuery query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider(query));
    return tracks.when(
      loading: () => const LoadingList(),
      error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(tracksProvider(query))),
      data: (list) => list.isEmpty
          ? EmptyState(
              icon: Icons.music_off_rounded,
              title: t3(appLang, 'Nothing here yet', 'अभी यहाँ कुछ नहीं', 'ఇక్కడ ఇంకా ఏమీ లేదు'),
              subtitle: t3(
                appLang,
                'More recordings are added as licensed content becomes available.',
                'लाइसेंस वाली सामग्री मिलते ही और रिकॉर्डिंग जोड़ी जाएँगी।',
                'లైసెన్స్ ఉన్న కంటెంట్ దొరికినప్పుడల్లా మరిన్ని రికార్డింగ్‌లు జోడిస్తాం.',
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(tracksProvider(query).future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24).withSystemInsets(context),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => TrackTile(
                  track: list[i],
                  queue: list,
                  index: i,
                  from: 'browse',
                ).animate().fadeIn(delay: (30 * i.clamp(0, 10)).ms).slideY(begin: 0.08),
              ),
            ),
    );
  }
}

/// Cached image provider for small avatars.
class NetworkImageProvider extends ResizeImage {
  NetworkImageProvider(String url) : super(NetworkImage(url), width: 96);
}
