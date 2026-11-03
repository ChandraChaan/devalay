import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/sfx.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';

/// Virtual Mandir: light a diya, offer flowers, ring the bell, blow the shankh
/// and perform aarti. Works fully offline once deity images are cached.
class MandirScreen extends ConsumerStatefulWidget {
  const MandirScreen({super.key});
  @override
  ConsumerState<MandirScreen> createState() => _MandirScreenState();
}

class _MandirScreenState extends ConsumerState<MandirScreen> with TickerProviderStateMixin {
  late final _flame = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  late final _bell = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final _flowers = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final _aarti = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final _shankh = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  final _page = PageController(viewportFraction: 0.82);
  bool _diyaLit = false;
  int _index = 0;
  List<_Petal> _petals = const [];
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _streak = _recordVisit();
    final ishta = ref.read(prefsProvider).ishtaDevta;
    ref.read(deitiesProvider.future).then((all) {
      final list = _shrineDeities(all);
      final i = list.indexWhere((d) => d.slug == ishta);
      if (i > 0 && mounted) {
        setState(() => _index = i);
        _page.jumpToPage(i);
      }
    });
  }

  /// Counts consecutive days with a darshan, stored only on the device.
  int _recordVisit() {
    final today = DateUtils.dateOnly(DateTime.now());
    final last = DateTime.tryParse(Boxes.stats.get('mandir_last', defaultValue: '') as String);
    var streak = Boxes.stats.get('mandir_streak', defaultValue: 0) as int;
    if (last == null || today.difference(last).inDays > 1) {
      streak = 1;
    } else if (today.difference(last).inDays == 1) {
      streak += 1;
    }
    Boxes.stats.put('mandir_last', today.toIso8601String());
    Boxes.stats.put('mandir_streak', streak);
    return streak;
  }

  List<Deity> _shrineDeities(List<Deity> all) =>
      all.where((d) => d.slug != 'general' && d.imageUrl.isNotEmpty).toList();

  @override
  void dispose() {
    for (final c in [_flame, _bell, _flowers, _aarti, _shankh]) {
      c.dispose();
    }
    _page.dispose();
    Sfx.stopAll();
    super.dispose();
  }

  void _lightDiya() {
    HapticFeedback.mediumImpact();
    setState(() => _diyaLit = !_diyaLit);
  }

  void _offerFlowers() {
    HapticFeedback.lightImpact();
    final rnd = math.Random();
    setState(() => _petals = List.generate(36, (_) => _Petal.random(rnd)));
    _flowers.forward(from: 0);
  }

  void _ringBell() {
    HapticFeedback.heavyImpact();
    Sfx.play('temple-bell');
    _bell.forward(from: 0);
  }

  void _blowShankh() {
    HapticFeedback.mediumImpact();
    Sfx.play('shankh');
    _shankh.forward(from: 0);
  }

  Future<void> _doAarti() async {
    if (_aarti.isAnimating) {
      _aarti.stop();
      await Sfx.stop('ghanti');
      setState(() {});
      return;
    }
    setState(() => _diyaLit = true);
    Sfx.play('ghanti', loop: true, volume: 0.7);
    await _aarti.repeat(count: 3);
    await Sfx.stop('ghanti');
    _ringBell();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final deities = ref.watch(deitiesProvider);
    final lang = ref.watch(prefsProvider).language;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0A04),
        body: deities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(deitiesProvider)),
          data: (all) {
            final list = _shrineDeities(all);
            if (list.isEmpty) return const SizedBox.shrink();
            final deity = list[_index.clamp(0, list.length - 1)];
            final glow = Palette.hex(deity.color);
            return Stack(
              children: [
                Positioned.fill(child: _TempleBackdrop(glow: glow)),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t3(lang, 'My Mandir', 'मेरा मंदिर', 'నా మందిరం'),
                                    style: const TextStyle(
                                      color: Palette.gold,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(deity.label(lang), style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                '🔥 $_streak ${t3(lang, 'day streak', 'दिन', 'రోజుల వరుస')}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PageView.builder(
                              controller: _page,
                              itemCount: list.length,
                              onPageChanged: (i) {
                                HapticFeedback.selectionClick();
                                setState(() => _index = i);
                              },
                              itemBuilder: (_, i) => AnimatedBuilder(
                                animation: _page,
                                builder: (_, child) {
                                  final page = _page.hasClients && _page.position.haveDimensions
                                      ? _page.page!
                                      : _index.toDouble();
                                  final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
                                  return Transform.scale(
                                    scale: 0.86 + 0.14 * t,
                                    child: Opacity(opacity: 0.4 + 0.6 * t, child: child),
                                  );
                                },
                                child: _Shrine(deity: list[i], glow: Palette.hex(list[i].color)),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 24,
                              child: _Bell(controller: _bell, onTap: _ringBell),
                            ),
                            Positioned(
                              top: 0,
                              right: 24,
                              child: _Bell(controller: _bell, onTap: _ringBell, mirror: true),
                            ),
                            Positioned(
                              bottom: 6,
                              child: _Diya(lit: _diyaLit, flame: _flame),
                            ),
                            IgnorePointer(
                              child: _AartiFlame(controller: _aarti, flame: _flame),
                            ),
                            IgnorePointer(child: _ShankhWaves(controller: _shankh)),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: _FlowerShower(controller: _flowers, petals: _petals),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Action(emoji: '🪔', label: tr(ref, 'light_diya'), active: _diyaLit, onTap: _lightDiya),
                            _Action(emoji: '🌼', label: tr(ref, 'offer_flowers'), onTap: _offerFlowers),
                            _Action(emoji: '🔔', label: tr(ref, 'ring_bell'), onTap: _ringBell),
                            _Action(emoji: '🐚', label: tr(ref, 'blow_shankh'), onTap: _blowShankh),
                            _Action(
                              emoji: '🙏',
                              label: tr(ref, 'do_aarti'),
                              active: _aarti.isAnimating,
                              onTap: _doAarti,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TempleBackdrop extends StatelessWidget {
  const _TempleBackdrop({required this.glow});
  final Color glow;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.1,
          colors: [glow.withValues(alpha: 0.55), const Color(0xFF2A0F06), const Color(0xFF120603)],
        ),
      ),
      child: CustomPaint(painter: _ToranPainter()),
    );
  }
}

/// Marigold garland (toran) and temple arch outline.
class _ToranPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sits just below the header row (title and streak).
    final top = MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).padding.top + 130;
    final arch = Paint()
      ..color = Palette.gold.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.8)
      ..lineTo(size.width * 0.08, top + 60)
      ..quadraticBezierTo(size.width * 0.5, top - 40, size.width * 0.92, top + 60)
      ..lineTo(size.width * 0.92, size.height * 0.8);
    canvas.drawPath(path, arch);
    final colors = [const Color(0xFFFF9800), const Color(0xFFFFC107), const Color(0xFFE65100)];
    for (var swag = 0; swag < 4; swag++) {
      final x0 = size.width * swag / 4;
      final x1 = size.width * (swag + 1) / 4;
      for (var i = 0; i <= 12; i++) {
        final t = i / 12;
        final x = x0 + (x1 - x0) * t;
        final y = top - 50 + math.sin(t * math.pi) * 28;
        canvas.drawCircle(Offset(x, y), 7, Paint()..color = colors[(i + swag) % 3]);
      }
      final leaf = Paint()..color = const Color(0xFF2E7D32);
      canvas.drawOval(Rect.fromCenter(center: Offset(x1, top - 42), width: 10, height: 22), leaf);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Shrine extends StatelessWidget {
  const _Shrine({required this.deity, required this.glow});
  final Deity deity;
  final Color glow;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Mandala(size: 320, color: Palette.gold, opacity: 0.22),
          Hero(
            tag: 'deity-${deity.slug}',
            child: Container(
              width: 230,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(120), bottom: Radius.circular(18)),
                border: Border.all(color: Palette.gold, width: 5),
                boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.7), blurRadius: 50, spreadRadius: 4)],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(115), bottom: Radius.circular(14)),
                child: NetImage(deity.imageUrl, color: glow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.controller, required this.onTap, this.mirror = false});
  final AnimationController controller;
  final VoidCallback onTap;
  final bool mirror;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, child) {
          final t = controller.value;
          final angle = math.sin(t * math.pi * 6) * 0.45 * (1 - t) * (mirror ? -1 : 1);
          return Transform.rotate(angle: angle, alignment: Alignment.topCenter, child: child);
        },
        child: Column(
          children: [
            Container(width: 2, height: 40, color: Palette.gold.withValues(alpha: 0.7)),
            const Text('🔔', style: TextStyle(fontSize: 40)),
          ],
        ),
      ),
    );
  }
}

class _Diya extends StatelessWidget {
  const _Diya({required this.lit, required this.flame});
  final bool lit;
  final AnimationController flame;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 110,
      child: AnimatedBuilder(
        animation: flame,
        builder: (_, _) => CustomPaint(
          painter: _DiyaPainter(lit: lit, t: flame.value),
        ),
      ),
    );
  }
}

class _DiyaPainter extends CustomPainter {
  _DiyaPainter({required this.lit, required this.t});
  final bool lit;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (lit) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [Palette.gold.withValues(alpha: 0.55), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.35), radius: w * 0.6));
      canvas.drawCircle(Offset(w / 2, h * 0.35), w * 0.6, glow);
      final flicker = math.sin(t * 2 * math.pi) * 0.06 + math.sin(t * 6 * math.pi) * 0.03;
      final fh = h * (0.42 + flicker);
      final base = Offset(w / 2, h * 0.62);
      final flamePath = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx - w * 0.13, base.dy - fh * 0.45, base.dx + flicker * 40, base.dy - fh)
        ..quadraticBezierTo(base.dx + w * 0.13, base.dy - fh * 0.45, base.dx, base.dy);
      canvas.drawPath(
        flamePath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFC107), Color(0xFFFF6D00)],
          ).createShader(Rect.fromLTWH(0, base.dy - fh, w, fh)),
      );
    }
    final bowl = Path()
      ..moveTo(w * 0.1, h * 0.62)
      ..quadraticBezierTo(w * 0.5, h * 1.05, w * 0.9, h * 0.62)
      ..quadraticBezierTo(w * 0.78, h * 0.58, w * 0.62, h * 0.66)
      ..lineTo(w * 0.38, h * 0.66)
      ..quadraticBezierTo(w * 0.22, h * 0.58, w * 0.1, h * 0.62)
      ..close();
    canvas.drawPath(
      bowl,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFBF5B04), Color(0xFF8D3B00)],
        ).createShader(Rect.fromLTWH(0, h * 0.55, w, h * 0.45)),
    );
    canvas.drawLine(
      Offset(w * 0.5, h * 0.66),
      Offset(w * 0.5, h * 0.6),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_DiyaPainter old) => old.lit != lit || old.t != t;
}

class _AartiFlame extends StatelessWidget {
  const _AartiFlame({required this.controller, required this.flame});
  final AnimationController controller;
  final AnimationController flame;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, flame]),
      builder: (_, _) {
        if (!controller.isAnimating) return const SizedBox.shrink();
        final a = controller.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(math.cos(a) * 110, math.sin(a) * 140 + 20),
          child: SizedBox(
            width: 70,
            height: 64,
            child: CustomPaint(painter: _DiyaPainter(lit: true, t: flame.value)),
          ),
        );
      },
    );
  }
}

class _ShankhWaves extends StatelessWidget {
  const _ShankhWaves({required this.controller});
  final AnimationController controller;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        if (controller.value == 0 || controller.value == 1) return const SizedBox.shrink();
        return CustomPaint(size: const Size(360, 360), painter: _WavePainter(controller.value));
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final p = ((t + i / 3) % 1);
      canvas.drawCircle(
        size.center(Offset.zero),
        60 + p * 140,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Palette.gold.withValues(alpha: (1 - p) * 0.6 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

class _Petal {
  _Petal(this.x, this.delay, this.speed, this.size, this.spin, this.emoji);
  final double x, delay, speed, size, spin;
  final String emoji;
  static _Petal random(math.Random r) => _Petal(
    r.nextDouble(),
    r.nextDouble() * 0.35,
    0.6 + r.nextDouble() * 0.6,
    18 + r.nextDouble() * 16,
    (r.nextDouble() - 0.5) * 8,
    ['🌼', '🌸', '🏵️', '🌺'][r.nextInt(4)],
  );
}

class _FlowerShower extends StatelessWidget {
  const _FlowerShower({required this.controller, required this.petals});
  final AnimationController controller;
  final List<_Petal> petals;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        return AnimatedBuilder(
          animation: controller,
          builder: (_, _) {
            if (!controller.isAnimating) return const SizedBox.shrink();
            final t = controller.value;
            return Stack(
              children: [
                for (final p in petals)
                  if (t > p.delay)
                    Positioned(
                      left: p.x * box.maxWidth + math.sin((t - p.delay) * 10 + p.x * 6) * 18,
                      top: ((t - p.delay) * p.speed * 1.6) * box.maxHeight - 40,
                      child: Transform.rotate(
                        angle: (t - p.delay) * p.spin,
                        child: Opacity(
                          opacity: (1 - t).clamp(0, 1) * 1.0,
                          child: Text(p.emoji, style: TextStyle(fontSize: p.size)),
                        ),
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.emoji, required this.label, required this.onTap, this.active = false});
  final String emoji, label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Palette.gold.withValues(alpha: 0.3) : Colors.white10,
              border: Border.all(color: active ? Palette.gold : Colors.white24, width: 1.5),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.1),
            ),
          ),
        ],
      ),
    ).animate(target: active ? 1 : 0).scaleXY(end: 1.06, duration: 200.ms);
  }
}
