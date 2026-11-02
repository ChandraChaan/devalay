import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative mandala drawn with petals and rings; optionally rotates slowly.
class Mandala extends StatefulWidget {
  const Mandala({super.key, this.size = 220, this.color = Colors.white, this.opacity = 0.15, this.spin = true});
  final double size;
  final Color color;
  final double opacity;
  final bool spin;

  @override
  State<Mandala> createState() => _MandalaState();
}

class _MandalaState extends State<Mandala> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 90));

  @override
  void initState() {
    super.initState();
    if (widget.spin) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Transform.rotate(
          angle: _c.value * 2 * math.pi,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: MandalaPainter(widget.color.withValues(alpha: widget.opacity)),
          ),
        ),
      ),
    );
  }
}

class MandalaPainter extends CustomPainter {
  MandalaPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()..color = color.withValues(alpha: color.a * 0.5);
    for (final ring in [0.18, 0.42, 0.72, 0.98]) {
      canvas.drawCircle(c, r * ring, stroke);
    }
    void petals(int n, double inner, double outer, double width) {
      for (var i = 0; i < n; i++) {
        final a = i * 2 * math.pi / n;
        final path = Path();
        final p0 = c + Offset(math.cos(a), math.sin(a)) * r * inner;
        final p1 = c + Offset(math.cos(a), math.sin(a)) * r * outer;
        final side = Offset(-math.sin(a), math.cos(a)) * r * width;
        final mid = Offset.lerp(p0, p1, 0.5)!;
        path
          ..moveTo(p0.dx, p0.dy)
          ..quadraticBezierTo((mid + side).dx, (mid + side).dy, p1.dx, p1.dy)
          ..quadraticBezierTo((mid - side).dx, (mid - side).dy, p0.dx, p0.dy);
        canvas.drawPath(path, stroke);
        if (n <= 8) canvas.drawPath(path, fill);
      }
    }

    petals(8, 0.18, 0.42, 0.1);
    petals(16, 0.42, 0.72, 0.07);
    petals(32, 0.72, 0.98, 0.035);
    for (var i = 0; i < 32; i++) {
      final a = i * 2 * math.pi / 32 + math.pi / 32;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.85, r * 0.015, fill);
    }
  }

  @override
  bool shouldRepaint(MandalaPainter old) => old.color != color;
}
