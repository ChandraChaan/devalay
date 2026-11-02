import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../widgets/common.dart';
import '../widgets/track_tile.dart';

const _kinds = [null, 'aarti', 'mantra', 'bhajan', 'dhun', 'ambient'];

class ListenScreen extends ConsumerStatefulWidget {
  const ListenScreen({super.key});
  @override
  ConsumerState<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends ConsumerState<ListenScreen> {
  String? _deity;

  @override
  Widget build(BuildContext context) {
    final deities = ref.watch(deitiesProvider).value ?? const <Deity>[];
    final hi = ref.watch(prefsProvider).language == 'hi';
    return DefaultTabController(
      length: _kinds.length,
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
                            label: Text(hi ? d.nameHi : d.name),
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
          ? const EmptyState(
              icon: Icons.music_off_rounded,
              title: 'Nothing here yet',
              subtitle: 'More recordings are added as licensed content becomes available.',
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(tracksProvider(query).future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => TrackTile(
                  track: list[i],
                  queue: list,
                  index: i,
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
