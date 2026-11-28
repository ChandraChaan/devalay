import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/billing.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/native.dart';
import '../core/sections.dart';
import '../core/sharing.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import '../widgets/premium_lock.dart';
import 'section_common.dart';

/// HD wallpapers: public-domain and CC BY devotional art composed for 20:9 phones. Free wallpapers
/// download in FHD+ (1080×2400); Premium unlocks the top five and QHD+ (1440×3200) for every one.
class WallpaperGalleryScreen extends ConsumerStatefulWidget {
  const WallpaperGalleryScreen({super.key, this.openId});

  /// Opens this wallpaper straight away (from a favourite or a deep link).
  final String? openId;

  @override
  ConsumerState<WallpaperGalleryScreen> createState() => _WallpaperGalleryScreenState();
}

class _WallpaperGalleryScreenState extends ConsumerState<WallpaperGalleryScreen> {
  String _filter = SectionFilter.all;
  bool _opened = false;

  void _open(List<HdWallpaper> list, int index) {
    final w = list[index];
    if (isLocked(w, premium: ref.read(premiumProvider))) logLockTap(w);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WallpaperViewer(items: list, initial: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    ref.watch(sectionDownloadsTick);
    final favs = ref.watch(favoritesProvider);
    final catalog = ref.watch(sectionsProvider);
    final tags = ref.watch(sectionTodayTagsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'wallpapers')),
        bottom: catalog.value == null
            ? null
            : SectionChips(
                extra: [
                  ('style:modern', t3(lang, 'Modern', 'मॉडर्न', 'మోడర్న్'), Icons.auto_awesome_rounded),
                  ('style:photo', t3(lang, 'Photos', 'फ़ोटो', 'ఫోటోలు'), Icons.photo_camera_rounded),
                  (
                    'style:classic',
                    t3(lang, 'Classic art', 'क्लासिक चित्र', 'సంప్రదాయ చిత్రాలు'),
                    Icons.palette_rounded,
                  ),
                ],
                deities: deitiesOf(catalog.value!.wallpapers),
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
              ),
      ),
      body: catalog.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(sectionsProvider)),
        data: (c) {
          final all = c.wallpapers;
          if (!_opened && widget.openId != null) {
            _opened = true;
            final i = all.indexWhere((w) => w.id == widget.openId);
            if (i >= 0) WidgetsBinding.instance.addPostFrameCallback((_) => _open(all, i));
          }
          final shown = _filter.startsWith('style:')
              ? all.where((w) => w.style == _filter.substring(6)).toList()
              : SectionFilter.apply(
                  all,
                  _filter,
                  todayTags: tags,
                  isFavourite: (w) => favs.containsKey('${favouriteType(w)}:${w.id}'),
                  isDownloaded: (w) => SectionFiles.isDownloaded(w.fhd) || SectionFiles.isDownloaded(w.qhd),
                );
          final top = _filter == SectionFilter.all;
          final featured = top ? all.where((w) => w.isPremium).toList() : const <HdWallpaper>[];
          final today = top ? forToday(all.where((w) => !w.isPremium).toList(), tags) : const <HdWallpaper>[];
          final grid = top ? shown.where((w) => !w.isPremium).toList() : shown;
          return CustomScrollView(
            slivers: [
              if (featured.isNotEmpty) ...[
                SliverToBoxAdapter(child: PremiumCollectionHeader(premium: premium)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: featured.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 144,
                        child: _WallTile(w: featured[i], locked: !premium, big: true, onTap: () => _open(featured, i)),
                      ),
                    ),
                  ),
                ),
              ],
              if (today.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionHeader(t3(lang, 'For today', 'आज के लिए', 'ఈ రోజు కోసం'))),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 230,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: today.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => SizedBox(
                        width: 104,
                        child: _WallTile(w: today[i], locked: false, onTap: () => _open(today, i)),
                      ),
                    ),
                  ),
                ),
              ],
              if (top)
                SliverToBoxAdapter(
                  child: SectionHeader(t3(lang, 'All wallpapers', 'सभी वॉलपेपर', 'అన్ని వాల్‌పేపర్లు')),
                ),
              if (grid.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.wallpaper_rounded,
                    title: t3(lang, 'Nothing here yet', 'अभी कुछ नहीं', 'ఇక్కడ ఇంకా ఏమీ లేవు'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16).withSystemInsets(context),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.45,
                    ),
                    itemCount: grid.length,
                    itemBuilder: (_, i) => _WallTile(
                      w: grid[i],
                      locked: isLocked(grid[i], premium: premium),
                      onTap: () => _open(grid, i),
                    ).animate().fadeIn(delay: (30 * (i % 9)).ms),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WallTile extends ConsumerWidget {
  const _WallTile({required this.w, required this.locked, required this.onTap, this.big = false});
  final HdWallpaper w;
  final bool locked, big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final downloaded = SectionFiles.isDownloaded(w.fhd) || SectionFiles.isDownloaded(w.qhd);
    return Semantics(
      button: true,
      label: '${w.title.of(lang)}${w.isPremium ? ', Premium' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'hdwall-${w.id}',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: w.isPremium ? Border.all(color: const Color(0xFFFFC857), width: 1.6) : null,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(w.thumb, color: Palette.hex(w.color)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Text(
                        w.title.of(lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: big ? 14 : 12,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (w.isPremium)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: LockBadge(locked: locked, compact: !big),
                    ),
                  if (downloaded)
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.download_done_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen wallpapers, swipe for the next. Locked ones show a watermarked preview and Unlock.
class WallpaperViewer extends ConsumerStatefulWidget {
  const WallpaperViewer({super.key, required this.items, required this.initial});
  final List<HdWallpaper> items;
  final int initial;
  @override
  ConsumerState<WallpaperViewer> createState() => _WallpaperViewerState();
}

class _WallpaperViewerState extends ConsumerState<WallpaperViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  double? _progress;
  bool _busy = false;

  HdWallpaper get _w => widget.items[_index];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// QHD+ for Premium, FHD+ otherwise; kept in app storage, so it works offline afterwards.
  Future<File> _file() async {
    final url = ref.read(premiumProvider) ? _w.qhd : _w.fhd;
    final f = await SectionFiles.get(url, onProgress: (p) => mounted ? setState(() => _progress = p) : null);
    ref.read(sectionDownloadsTick.notifier).bump();
    return f;
  }

  Future<void> _run(Future<void> Function(File f) action, String done) async {
    setState(() {
      _busy = true;
      _progress = null;
    });
    try {
      await action(await _file());
      HapticFeedback.mediumImpact();
      if (mounted && done.isNotEmpty) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, t3(appLang, 'Could not complete: $e', 'पूरा नहीं हो सका: $e', 'పూర్తి కాలేదు: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setAs() {
    final lang = uiLang(ref);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (target, label, icon) in [
              (1, t3(lang, 'Home screen', 'होम स्क्रीन', 'హోమ్ స్క్రీన్'), Icons.home_rounded),
              (2, t3(lang, 'Lock screen', 'लॉक स्क्रीन', 'లాక్ స్క్రీన్'), Icons.lock_rounded),
              (3, t3(lang, 'Both', 'दोनों', 'రెండూ'), Icons.phone_android_rounded),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.pop(ctx);
                  final w = _w;
                  _run((f) async {
                    await NativeBridge.setWallpaper(f.path, target);
                    Usage.record('wallpaper_set', item: '${w.id}:$target');
                  }, t3(lang, 'Wallpaper set 🙏', 'वॉलपेपर लग गया 🙏', 'వాల్‌పేపర్ పెట్టాం 🙏'));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    final w = _w;
    final locked = isLocked(w, premium: premium);
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
            item: favouriteFor(w, lang, image: w.thumb),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final itemLocked = isLocked(item, premium: premium);
              return Hero(
                tag: 'hdwall-${item.id}',
                child: PremiumWatermark(
                  enabled: itemLocked,
                  child: InteractiveViewer(
                    maxScale: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NetImage(item.thumb, color: Palette.hex(item.color)),
                        NetImage(item.fhd),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 48, 16, 16 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000), Color(0xEE000000)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          w.title.of(lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (w.isPremium) ...[const SizedBox(width: 8), LockBadge(locked: locked, compact: true)],
                    ],
                  ),
                  CreditLine(w.credit, light: true),
                  const SizedBox(height: 12),
                  if (_busy) ...[LinearProgressIndicator(value: _progress), const SizedBox(height: 8)],
                  if (locked) ...[
                    Text(
                      t3(
                        lang,
                        'Preview. Premium removes the watermark and unlocks QHD+ downloads.',
                        'यह झलक है। प्रीमियम से वॉटरमार्क हटता है और QHD+ डाउनलोड मिलते हैं।',
                        'ఇది ప్రివ్యూ. ప్రీమియంతో వాటర్‌మార్క్ ఉండదు, QHD+ డౌన్‌లోడ్ వస్తుంది.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    UnlockButton(item: w),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _setAs,
                            icon: const Icon(Icons.wallpaper_rounded),
                            label: Text(t3(lang, 'Set wallpaper', 'वॉलपेपर लगाएँ', 'వాల్‌పేపర్ పెట్టండి')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: premium
                              ? t3(lang, 'Save QHD+', 'QHD+ सेव करें', 'QHD+ సేవ్')
                              : t3(lang, 'Save to gallery', 'गैलरी में सहेजें', 'గ్యాలరీలో సేవ్'),
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (f) async {
                                    await NativeBridge.saveImage(f.path, 'devalay-${w.id}.jpg');
                                    Usage.record('wallpaper_save', item: w.id);
                                  },
                                  t3(
                                    lang,
                                    'Saved to Pictures/Devalay',
                                    'Pictures/Devalay में सहेजा',
                                    'Pictures/Devalayలో సేవ్ అయింది',
                                  ),
                                ),
                          icon: const Icon(Icons.download_rounded),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'WhatsApp',
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (f) => shareFileToWhatsApp(
                                    f,
                                    mime: 'image/jpeg',
                                    text: '🙏 ${w.title.of(lang)}\n\n${shareFooter('wallpaper')}',
                                    what: itemRef(w),
                                  ),
                                  '',
                                ),
                          icon: const Icon(Icons.share_rounded),
                        ),
                      ],
                    ),
                  if (!premium && !locked)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        t3(
                          lang,
                          'FHD+ 1080×2400 · QHD+ with Premium',
                          'FHD+ 1080×2400 · प्रीमियम में QHD+',
                          'FHD+ 1080×2400 · ప్రీమియంలో QHD+',
                        ),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
