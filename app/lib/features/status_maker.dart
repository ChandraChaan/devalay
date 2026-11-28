import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../core/sharing.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';

/// Renders the 9:16 picture under [boundary] at 1080 pixels wide (1080×1920) into a temporary PNG.
/// Shared by the status composer and festival wishes.
Future<File> renderStatusImage(GlobalKey boundary, {String prefix = 'devalay-status'}) async {
  final box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await box.toImage(pixelRatio: 1080 / box.size.width);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  final file = File('${(await getTemporaryDirectory()).path}/$prefix-${DateTime.now().millisecondsSinceEpoch}.png');
  return file.writeAsBytes(bytes);
}

/// Copies a rendered image into Pictures/Devalay.
Future<void> saveToGallery(File file) => NativeBridge.saveImage(file.path, file.uri.pathSegments.last);

/// Composes the status text over sacred art and exports it as a 1080x1920 image.
class StatusComposer extends ConsumerStatefulWidget {
  const StatusComposer({super.key, required this.text, required this.deity, this.image, this.footnote});
  final String text;
  final String deity;

  /// Smaller text under [text], such as a verse's meaning.
  final String? footnote;

  /// A wallpaper to write on; it becomes the first background.
  final String? image;
  @override
  ConsumerState<StatusComposer> createState() => _StatusComposerState();
}

class _StatusComposerState extends ConsumerState<StatusComposer> {
  final _boundary = GlobalKey();
  int _bg = 0;
  bool _busy = false;
  static const _gradients = [
    Palette.sunrise,
    Palette.dusk,
    Palette.sky,
    Palette.tulsi,
    [Color(0xFF212121), Color(0xFF5D4037)],
  ];

  Future<File> _render() => renderStatusImage(_boundary);

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final f = await _render();
      await shareContent(
        [widget.text, ?widget.footnote, shareFooter('status')].join('\n\n'),
        files: [XFile(f.path)],
        what: 'status',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await saveToGallery(await _render());
      HapticFeedback.mediumImpact();
      if (mounted) {
        toast(
          context,
          t3(appLang, 'Saved to Pictures/Devalay', 'Pictures/Devalay में सहेजा गया', 'Pictures/Devalayలో సేవ్ అయింది'),
        );
      }
    } catch (e) {
      if (mounted) toast(context, t3(appLang, 'Could not save: $e', 'सहेजा नहीं जा सका: $e', 'సేవ్ కాలేదు: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setAsWallpaper() {
    final lang = uiLang(ref);
    showModalBottomSheet(
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
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _busy = true);
                  try {
                    final f = await _render();
                    await NativeBridge.setWallpaper(f.path, target);
                    if (mounted) {
                      toast(context, t3(lang, 'Wallpaper set 🙏', 'वॉलपेपर लग गया 🙏', 'వాల్‌పేపర్ పెట్టాం 🙏'));
                    }
                  } catch (e) {
                    if (mounted) {
                      toast(context, t3(appLang, 'Could not set: $e', 'लगाया नहीं जा सका: $e', 'పెట్టలేకపోయాం: $e'));
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
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
    final walls =
        ref
            .watch(
              wallpapersProvider(widget.deity == 'general' || widget.deity == 'radha-krishna' ? null : widget.deity),
            )
            .value ??
        const <Wallpaper>[];
    final backgrounds = [
      if (widget.image != null) ('w', const <Color>[], widget.image!),
      for (final g in _gradients) ('g', g, ''),
      for (final w in walls.take(6))
        if (w.imageUrl != widget.image) ('w', const <Color>[], w.imageUrl),
    ];
    final current = backgrounds[_bg.clamp(0, backgrounds.length - 1)];
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Status', 'स्टेटस', 'స్టేటస్'))),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: RepaintBoundary(
                  key: _boundary,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (current.$1 == 'g')
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: current.$2,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          )
                        else
                          NetImage(current.$3),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.65)],
                            ),
                          ),
                        ),
                        const Positioned(
                          top: -60,
                          right: -60,
                          child: Mandala(size: 260, color: Palette.gold, opacity: 0.3),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Text(
                                'ॐ',
                                style: TextStyle(fontFamily: scriptureFont, fontSize: 40, color: Palette.gold),
                              ),
                              const Spacer(),
                              // Long verses shrink to fit the 9:16 card instead of overflowing.
                              Flexible(
                                flex: 6,
                                child: LayoutBuilder(
                                  builder: (context, c) => FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: c.maxWidth),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                                widget.text,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontFamilyFallback: uiFontFallback,
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  height: 1.45,
                                                  fontWeight: FontWeight.w700,
                                                  shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                                                ),
                                              )
                                              .animate(onPlay: (c) => c.repeat(reverse: true))
                                              .shimmer(duration: 2400.ms, color: Palette.gold.withValues(alpha: 0.6)),
                                          if (widget.footnote case final note?) ...[
                                            const SizedBox(height: 16),
                                            Text(
                                              note,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontFamilyFallback: uiFontFallback,
                                                color: Colors.white,
                                                fontSize: 16,
                                                height: 1.4,
                                                shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text('🪔 Devalay', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: backgrounds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _bg = i),
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: i == _bg ? Palette.saffron : Colors.transparent, width: 3),
                    gradient: backgrounds[i].$1 == 'g' ? LinearGradient(colors: backgrounds[i].$2) : null,
                  ),
                  child: backgrounds[i].$1 == 'w' ? NetImage(backgrounds[i].$3, radius: 7) : null,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16).withSystemInsets(context),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(t3(lang, 'Save', 'सेव', 'సేవ్')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _setAsWallpaper,
                    icon: const Icon(Icons.wallpaper_rounded),
                    label: Text(t3(lang, 'Wallpaper', 'वॉलपेपर', 'వాల్‌పేపర్')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.share_rounded),
                    label: Text(t3(lang, 'Share', 'शेयर', 'షేర్')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
