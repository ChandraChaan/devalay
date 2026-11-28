import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../core/about_you.dart';
import '../core/billing.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/sections.dart';
import '../core/sharing.dart';
import '../core/status_library.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import '../widgets/premium_lock.dart';
import '../widgets/status_templates.dart';
import 'section_common.dart';

/// WhatsApp Status: ready 9:16 1080p status videos (slow zoom on the art, typeset Telugu or Hindi verse,
/// licensed audio), and image statuses for today drawn on the phone in the reader's language.
class WhatsAppStatusScreen extends ConsumerStatefulWidget {
  const WhatsAppStatusScreen({super.key, this.openId});
  final String? openId;
  @override
  ConsumerState<WhatsAppStatusScreen> createState() => _WhatsAppStatusScreenState();
}

class _WhatsAppStatusScreenState extends ConsumerState<WhatsAppStatusScreen> {
  String _filter = SectionFilter.all;
  bool _opened = false;

  void _open(List<StatusVideo> list, int index) {
    if (isLocked(list[index], premium: ref.read(premiumProvider))) logLockTap(list[index]);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusVideoPager(items: list, initial: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t3(lang, 'WhatsApp Status', 'व्हाट्सऐप स्टेटस', 'వాట్సాప్ స్టేటస్')),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.play_circle_rounded), text: t3(lang, 'Videos', 'वीडियो', 'వీడియోలు')),
              Tab(icon: const Icon(Icons.image_rounded), text: t3(lang, 'Images', 'तस्वीरें', 'చిత్రాలు')),
            ],
          ),
        ),
        body: TabBarView(children: [_videos(lang), const _TodayImages()]),
      ),
    );
  }

  Widget _videos(String lang) {
    final premium = ref.watch(premiumProvider);
    ref.watch(sectionDownloadsTick);
    final favs = ref.watch(favoritesProvider);
    final tags = ref.watch(sectionTodayTagsProvider);
    final catalog = ref.watch(sectionsProvider);
    return catalog.when(
      loading: () => const LoadingList(),
      error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(sectionsProvider)),
      data: (c) {
        // The reader's language first: Telugu readers see Telugu statuses before Hindi ones.
        final all = [
          ...c.statusVideos.where((v) => v.lang == lang || v.isPremium),
          ...c.statusVideos.where((v) => v.lang != lang && !v.isPremium),
        ];
        if (!_opened && widget.openId != null) {
          _opened = true;
          final i = all.indexWhere((v) => v.id == widget.openId);
          if (i >= 0) WidgetsBinding.instance.addPostFrameCallback((_) => _open(all, i));
        }
        final shown = SectionFilter.apply(
          all,
          _filter,
          todayTags: tags,
          isFavourite: (v) => favs.containsKey('${favouriteType(v)}:${v.id}'),
          isDownloaded: (v) => SectionFiles.isDownloaded(v.video),
        );
        final top = _filter == SectionFilter.all;
        final featured = top ? all.where((v) => v.isPremium).toList() : const <StatusVideo>[];
        final today = top ? forToday(all.where((v) => !v.isPremium).toList(), tags, max: 6) : const <StatusVideo>[];
        final grid = top ? shown.where((v) => !v.isPremium).toList() : shown;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SectionChips(
                deities: deitiesOf(all),
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
              ),
            ),
            if (featured.isNotEmpty) ...[
              SliverToBoxAdapter(child: PremiumCollectionHeader(premium: premium)),
              SliverToBoxAdapter(child: _row(featured, locked: !premium, height: 280)),
            ],
            if (today.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(t3(lang, 'For today', 'आज के लिए', 'ఈ రోజు కోసం'))),
              SliverToBoxAdapter(child: _row(today, locked: false, height: 230)),
            ],
            if (top) SliverToBoxAdapter(child: SectionHeader(t3(lang, 'All videos', 'सभी वीडियो', 'అన్ని వీడియోలు'))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16).withSystemInsets(context),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: grid.length,
                itemBuilder: (_, i) => _VideoTile(
                  v: grid[i],
                  locked: isLocked(grid[i], premium: premium),
                  onTap: () => _open(grid, i),
                ).animate().fadeIn(delay: (30 * (i % 9)).ms),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(List<StatusVideo> items, {required bool locked, required double height}) => SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, i) => SizedBox(
        width: height * 9 / 16,
        child: _VideoTile(v: items[i], locked: locked && items[i].isPremium, onTap: () => _open(items, i)),
      ),
    ),
  );
}

class _VideoTile extends ConsumerWidget {
  const _VideoTile({required this.v, required this.locked, required this.onTap});
  final StatusVideo v;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: v.isPremium ? Border.all(color: const Color(0xFFFFC857), width: 1.6) : null,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetImage(v.poster),
              const Center(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black45,
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Text(
                    v.title.of(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, height: 1.2),
                  ),
                ),
              ),
              if (v.isPremium) Positioned(top: 6, right: 6, child: LockBadge(locked: locked, compact: true)),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    SectionFiles.isDownloaded(v.video) ? '✓ ${v.seconds}s' : '${v.seconds}s',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status videos full screen, swipe up for the next, like a status feed.
class StatusVideoPager extends ConsumerStatefulWidget {
  const StatusVideoPager({super.key, required this.items, required this.initial});
  final List<StatusVideo> items;
  final int initial;
  @override
  ConsumerState<StatusVideoPager> createState() => _StatusVideoPagerState();
}

class _StatusVideoPagerState extends ConsumerState<StatusVideoPager> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: lightBars,
        actions: [
          FavoriteButton(
            color: Colors.white,
            item: favouriteFor(widget.items[_index], uiLang(ref), image: widget.items[_index].poster),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        scrollDirection: Axis.vertical,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => _VideoPage(v: widget.items[i], active: i == _index),
      ),
    );
  }
}

class _VideoPage extends ConsumerStatefulWidget {
  const _VideoPage({required this.v, required this.active});
  final StatusVideo v;
  final bool active;
  @override
  ConsumerState<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<_VideoPage> {
  VideoPlayerController? _c;
  bool _busy = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final v = widget.v;
    // Downloaded videos play from storage, so they work offline.
    final c = SectionFiles.isDownloaded(v.video)
        ? VideoPlayerController.file(await SectionFiles.get(v.video))
        : VideoPlayerController.networkUrl(Uri.parse(v.video));
    if (!mounted) return c.dispose();
    setState(() => _c = c);
    try {
      await c.initialize();
      await c.setLooping(true);
      if (widget.active && mounted) await c.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('status video: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _VideoPage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      widget.active ? _c?.play() : _c?.pause();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<File?> _file() async {
    setState(() {
      _busy = true;
      _progress = null;
    });
    try {
      final f = await SectionFiles.get(
        widget.v.video,
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      );
      ref.read(sectionDownloadsTick.notifier).bump();
      return f;
    } catch (e) {
      if (mounted) {
        toast(context, t3(appLang, 'Could not download: $e', 'डाउनलोड नहीं हुआ: $e', 'డౌన్‌లోడ్ కాలేదు: $e'));
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _whatsApp() async {
    final f = await _file();
    if (f == null) return;
    final v = widget.v;
    await shareFileToWhatsApp(f, mime: 'video/mp4', text: '🙏 ${v.text}\n\n${shareFooter('status')}', what: itemRef(v));
  }

  Future<void> _more() async {
    final f = await _file();
    if (f == null) return;
    final v = widget.v;
    await shareContent(
      '🙏 ${v.text}\n\n${shareFooter('status')}',
      files: [XFile(f.path, mimeType: 'video/mp4')],
      what: itemRef(v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final v = widget.v;
    final locked = isLocked(v, premium: ref.watch(premiumProvider));
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    // The video whole on top (its verse is part of the picture), the actions below it, never over it.
    return Column(
      children: [
        SizedBox(height: MediaQuery.paddingOf(context).top + kToolbarHeight),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => ready ? (c.value.isPlaying ? c.pause() : c.play()) : null,
                child: PremiumWatermark(
                  enabled: locked,
                  child: Center(
                    child: AspectRatio(aspectRatio: 9 / 16, child: ready ? VideoPlayer(c) : NetImage(v.poster)),
                  ),
                ),
              ),
              if (!ready) const Center(child: CircularProgressIndicator(color: Colors.white)),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ready) VideoProgressIndicator(c, allowScrubbing: false, padding: const EdgeInsets.only(bottom: 8)),
              Text(
                v.title.of(lang),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              CreditLine(v.artCredit, light: true, prefix: t3(lang, 'Art: ', 'चित्र: ', 'చిత్రం: ')),
              CreditLine(v.audioCredit, light: true, prefix: t3(lang, 'Audio: ', 'ऑडियो: ', 'ఆడియో: ')),
              const SizedBox(height: 10),
              if (_busy) ...[LinearProgressIndicator(value: _progress), const SizedBox(height: 8)],
              if (locked)
                UnlockButton(item: v)
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _busy ? null : _whatsApp,
                        icon: const Icon(Icons.send_rounded),
                        label: Text(
                          t3(lang, 'Share to WhatsApp', 'व्हाट्सऐप पर भेजें', 'వాట్సాప్‌లో పెట్టండి'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: t3(lang, 'More apps', 'अन्य ऐप', 'ఇతర యాప్‌లు'),
                      onPressed: _busy ? null : _more,
                      icon: const Icon(Icons.share_rounded),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Image statuses for today in the reader's language, drawn on the phone. A tap opens AI Status with
/// that design and verse, where the user adds their name and shares.
class _TodayImages extends ConsumerWidget {
  const _TodayImages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = statusLang(uiLang(ref));
    final premium = ref.watch(premiumProvider);
    final home = ref.watch(homeProvider).value;
    final name = ref.watch(aboutYouProvider).name;
    final festival = todayFestival(home);
    final walls = ref.watch(sectionsProvider).value?.wallpapers ?? const <HdWallpaper>[];
    final now = DateTime.now();
    final designs = [
      for (final (i, t) in StatusTemplate.values.indexed)
        (
          t,
          i % 4,
          composeStatus(
            lang: lang,
            day: now,
            festival: festival,
            panchang: home?['panchang'] as Map?,
            name: name,
            variant: i % 4,
          ),
        ),
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(12).withSystemInsets(context),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 9 / 16,
      ),
      itemCount: designs.length,
      itemBuilder: (_, i) {
        final (template, variant, content) = designs[i];
        final locked = template.isPremium && !premium;
        return GestureDetector(
          onTap: () {
            Usage.record('status_image_open', item: template.name);
            context.push('/status?template=${template.name}&variant=$variant');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PremiumWatermark(
                  enabled: locked,
                  child: StatusCard(
                    content: content,
                    template: template,
                    artUrl: artFor(walls, content.deity, premium, photo: template.prefersPhoto, thumb: true),
                  ),
                ),
                if (template.isPremium) Positioned(top: 6, right: 6, child: LockBadge(locked: locked, compact: true)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Status language: Telugu, Hindi or English (other app languages read the English card).
String statusLang(String lang) => const {'te', 'hi'}.contains(lang) ? lang : 'en';

/// A festival today, from the home feed, to greet.
StatusFestival? todayFestival(Map? home) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (final f in (home?['upcoming_festivals'] as List? ?? const []).cast<Map>()) {
    final d = DateTime.tryParse('${f['date']}');
    if (d == null || d != today) continue;
    final slug = '${f['slug']}';
    return (
      slug: slug,
      deity: '${f['deity'] ?? 'general'}',
      en: '${f['name']}',
      te: teluguFestivals[slug] ?? '${f['name']}',
      hi: '${f['name_hi'] ?? f['name']}',
    );
  }
  return null;
}

/// The deity's HD wallpaper for the art designs (a Premium one only for Premium members). [photo] prefers
/// a recent photograph or a modern design over a classic painting.
String? artFor(List<HdWallpaper> walls, String deity, bool premium, {bool photo = false, bool thumb = false}) {
  final fits = walls.where((w) => w.deity == deity && (premium || !w.isPremium)).toList();
  final pick = photo
      ? fits.where((w) => w.style == 'photo').firstOrNull
      : fits.where((w) => w.style == 'classic').firstOrNull;
  final w = pick ?? fits.firstOrNull ?? walls.where((w) => !w.isPremium).firstOrNull;
  return thumb ? w?.thumb : w?.fhd;
}
