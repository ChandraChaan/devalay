import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class WallpapersScreen extends ConsumerStatefulWidget {
  const WallpapersScreen({super.key});
  @override
  ConsumerState<WallpapersScreen> createState() => _WallpapersScreenState();
}

class _WallpapersScreenState extends ConsumerState<WallpapersScreen> {
  String? _deity;

  @override
  Widget build(BuildContext context) {
    final walls = ref.watch(wallpapersProvider(_deity));
    final deities = (ref.watch(deitiesProvider).value ?? const <Deity>[]).where((d) => d.slug != 'general').toList();
    final hi = ref.watch(prefsProvider).language == 'hi';
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'wallpapers')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tr(ref, 'all')),
                    selected: _deity == null,
                    onSelected: (_) => setState(() => _deity = null),
                  ),
                ),
                for (final d in deities)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(hi ? d.nameHi : d.name),
                      selected: _deity == d.slug,
                      onSelected: (_) => setState(() => _deity = d.slug),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: walls.when(
        loading: () => GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
          children: List.generate(6, (_) => const SkeletonBox()),
        ),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(wallpapersProvider(_deity))),
        data: (list) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final w = list[i];
            return GestureDetector(
              onTap: () => context.push('/wallpaper', extra: w),
              child: Hero(
                tag: 'wall-${w.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(w.thumbUrl, radius: 18, color: Palette.hex(w.color)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Text(
                          w.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (40 * (i % 8)).ms).scale(begin: const Offset(0.95, 0.95));
          },
        ),
      ),
    );
  }
}

class WallpaperDetailScreen extends ConsumerStatefulWidget {
  const WallpaperDetailScreen({super.key, required this.wallpaper});
  final Wallpaper wallpaper;
  @override
  ConsumerState<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends ConsumerState<WallpaperDetailScreen> {
  bool _busy = false;

  Future<String> _file() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/wallpaper-${widget.wallpaper.id}.jpg';
    if (!await File(path).exists()) {
      await Dio().download(widget.wallpaper.imageUrl, path);
    }
    return path;
  }

  Future<void> _run(Future<void> Function(String path) action, String done) async {
    setState(() => _busy = true);
    try {
      await action(await _file());
      ref.read(apiProvider).post('/wallpapers/${widget.wallpaper.id}/download').catchError((_) {});
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, 'Could not complete: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setAs() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (target, label, icon) in [
              (1, 'Home screen', Icons.home_rounded),
              (2, 'Lock screen', Icons.lock_rounded),
              (3, 'Both', Icons.phone_android_rounded),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.pop(ctx);
                  _run((p) => NativeBridge.setWallpaper(p, target), 'Wallpaper set 🙏');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallpaper;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          FavoriteButton(
            color: Colors.white,
            item: FavoriteItem(type: 'wallpaper', id: '${w.id}', title: w.title, image: w.thumbUrl),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'wall-${w.id}',
            child: InteractiveViewer(
              maxScale: 4,
              child: NetImage(w.imageUrl, fit: BoxFit.contain, alignment: Alignment.center),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    w.title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  Attribution(w, light: true),
                  const SizedBox(height: 12),
                  if (_busy) const LinearProgressIndicator(),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _setAs,
                          icon: const Icon(Icons.wallpaper_rounded),
                          label: const Text('Set as'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Save to gallery',
                        onPressed: _busy
                            ? null
                            : () => _run((p) async {
                                await NativeBridge.saveImage(p, 'devalay-${w.id}.jpg');
                              }, 'Saved to Pictures/Devalay'),
                        icon: const Icon(Icons.download_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Share',
                        onPressed: _busy
                            ? null
                            : () => _run((p) async {
                                await SharePlus.instance.share(
                                  ShareParams(files: [XFile(p)], text: '🙏 ${w.title} · via Devalay'),
                                );
                              }, 'Shared'),
                        icon: const Icon(Icons.share_rounded),
                      ),
                    ],
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
