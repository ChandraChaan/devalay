import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mandala.dart';

/// Festive decorations for wish cards, drawn in code so they are original, sharp at any size and
/// cost nothing to download. Each takes the card's size and the theme's accent colour. Names are
/// listed in `WishMotifs` (core/wishes.dart); an unknown name draws nothing.

const _marigold = Color(0xFFFF8F00);
const _marigoldLight = Color(0xFFFFC107);
const _leaf = Color(0xFF2E7D32);
const _leafLight = Color(0xFF7CB342);
const _clay = Color(0xFFB5541C);
const _clayDark = Color(0xFF6D2A0C);

/// A pattern across the whole card, behind everything else.
class WishBackdropPainter extends CustomPainter {
  WishBackdropPainter(this.kind, this.color);
  final String kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    switch (kind) {
      case 'mandala':
        void mandala(Offset c, double d, double alpha) {
          canvas.save();
          canvas.translate(c.dx - d / 2, c.dy - d / 2);
          MandalaPainter(color.withValues(alpha: alpha)).paint(canvas, Size.square(d));
          canvas.restore();
        }
        mandala(Offset(w / 2, h * 0.42), w * 1.45, 0.16);
        mandala(Offset.zero, w * 0.5, 0.14);
        mandala(Offset(w, h), w * 0.5, 0.14);
      case 'rays':
        final c = Offset(w / 2, h * 0.36);
        final paint = Paint()..color = color.withValues(alpha: 0.09);
        const n = 28;
        for (var i = 0; i < n; i += 2) {
          final a0 = i * 2 * math.pi / n, a1 = (i + 1) * 2 * math.pi / n;
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy)
              ..lineTo(c.dx + math.cos(a0) * h, c.dy + math.sin(a0) * h)
              ..lineTo(c.dx + math.cos(a1) * h, c.dy + math.sin(a1) * h)
              ..close(),
            paint,
          );
        }
        canvas.drawCircle(
          c,
          w * 0.6,
          Paint()
            ..shader = RadialGradient(
              colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
            ).createShader(Rect.fromCircle(center: c, radius: w * 0.6)),
        );
      case 'bokeh':
        final r = math.Random(7);
        for (var i = 0; i < 28; i++) {
          canvas.drawCircle(
            Offset(r.nextDouble() * w, r.nextDouble() * h),
            6 + r.nextDouble() * 26,
            Paint()
              ..color = color.withValues(alpha: 0.06 + r.nextDouble() * 0.16)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      case 'colors':
        const powders = [
          Color(0xFFE91E63),
          Color(0xFFFFC107),
          Color(0xFF43A047),
          Color(0xFF1E88E5),
          Color(0xFFFF5722),
          Color(0xFF8E24AA),
        ];
        final r = math.Random(3);
        for (var i = 0; i < 16; i++) {
          final c = powders[i % powders.length];
          final at = Offset(r.nextDouble() * w, r.nextDouble() * h);
          canvas.drawCircle(
            at,
            40 + r.nextDouble() * 70,
            Paint()
              ..color = c.withValues(alpha: 0.32)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
          );
          for (var j = 0; j < 7; j++) {
            canvas.drawCircle(
              at + Offset(r.nextDouble() * 120 - 60, r.nextDouble() * 120 - 60),
              1.5 + r.nextDouble() * 3.5,
              Paint()..color = c.withValues(alpha: 0.55),
            );
          }
        }
      case 'stars':
        final r = math.Random(11);
        for (var i = 0; i < 110; i++) {
          canvas.drawCircle(
            Offset(r.nextDouble() * w, r.nextDouble() * h * 0.8),
            0.5 + r.nextDouble() * 1.4,
            Paint()..color = Colors.white.withValues(alpha: 0.25 + r.nextDouble() * 0.65),
          );
        }
        for (var i = 0; i < 6; i++) {
          _sparkle(canvas, Offset(r.nextDouble() * w, r.nextDouble() * h * 0.6), 4 + r.nextDouble() * 4, Colors.white);
        }
    }
  }

  @override
  bool shouldRepaint(WishBackdropPainter old) => old.kind != kind || old.color != color;
}

/// The decoration along the top edge, and the one along the bottom edge.
class WishMotifPainter extends CustomPainter {
  WishMotifPainter({this.top = '', this.bottom = '', required this.accent});
  final String top, bottom;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    switch (top) {
      case 'toran':
        _toran(canvas, size);
      case 'sparkles':
        final r = math.Random(5);
        for (var i = 0; i < 16; i++) {
          final big = i % 4 == 0;
          _sparkle(
            canvas,
            Offset(r.nextDouble() * size.width, 6 + r.nextDouble() * 54),
            big ? 9 : 3 + r.nextDouble() * 4,
            i.isEven ? accent : Colors.white,
          );
        }
      case 'kites':
        _kite(canvas, Offset(size.width * 0.1, 34), 20, const Color(0xFFE91E63), const Color(0xFFFFEB3B), -0.25);
        _kite(canvas, Offset(size.width * 0.88, 30), 24, const Color(0xFF3949AB), const Color(0xFFFF9800), 0.2);
        _kite(canvas, Offset(size.width * 0.66, 20), 13, const Color(0xFF43A047), Colors.white, -0.1);
      case 'bells':
        for (final (x, drop, s) in [(0.16, 8.0, 0.62), (0.5, 12.0, 0.74), (0.84, 8.0, 0.62)]) {
          _bell(canvas, Offset(size.width * x, 0), drop, s);
        }
      case 'moon':
        final c = Offset(size.width - 46, 36);
        canvas.drawCircle(
          c,
          44,
          Paint()
            ..color = accent.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
        );
        canvas.drawCircle(
          c,
          24,
          Paint()
            ..shader = RadialGradient(
              colors: [Colors.white, Color.lerp(accent, Colors.white, 0.4)!],
              center: const Alignment(-0.3, -0.3),
            ).createShader(Rect.fromCircle(center: c, radius: 24)),
        );
      case 'crescent':
        final c = Offset(size.width - 46, 34);
        canvas.drawCircle(
          c,
          40,
          Paint()
            ..color = accent.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
        );
        canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: c, radius: 22)),
            Path()..addOval(Rect.fromCircle(center: c + const Offset(10, -7), radius: 19)),
          ),
          Paint()..color = Color.lerp(accent, Colors.white, 0.5)!,
        );
      case 'sun':
        final c = Offset(size.width - 46, 34);
        final glow = Paint()
          ..color = accent.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
        canvas.drawCircle(c, 40, glow);
        final ray = Paint()..color = accent.withValues(alpha: 0.85);
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi / 8;
          final d = Offset(math.cos(a), math.sin(a));
          final n = Offset(-d.dy, d.dx);
          canvas.drawPath(
            Path()
              ..moveTo((c + d * 22 + n * 4).dx, (c + d * 22 + n * 4).dy)
              ..lineTo((c + d * (i.isEven ? 32 : 27)).dx, (c + d * (i.isEven ? 32 : 27)).dy)
              ..lineTo((c + d * 22 - n * 4).dx, (c + d * 22 - n * 4).dy)
              ..close(),
            ray,
          );
        }
        canvas.drawCircle(c, 18, Paint()..color = accent);
        canvas.drawCircle(
          c,
          18,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case 'feather':
        _feather(canvas, Offset(size.width + 30, -10), Offset(size.width - 78, 38));
      case 'flags':
        _bunting(canvas, size);
    }

    switch (bottom) {
      case 'diyas':
        final y = size.height - 30;
        for (final (x, s) in [(0.12, 0.8), (0.31, 0.95), (0.5, 1.15), (0.69, 0.95), (0.88, 0.8)]) {
          _diya(canvas, Offset(size.width * x, y), 20 * s);
        }
      case 'rangoli':
        _rangoli(canvas, Offset(size.width / 2, size.height + 6), 80);
      case 'lotus':
        _lotus(canvas, Offset(size.width / 2, size.height - 12), 0.68);
      case 'pot':
        _pot(canvas, size);
      case 'kolam':
        _kolam(canvas, size);
      case 'rakhi':
        _rakhi(canvas, size);
      case 'garland':
        _garland(canvas, size);
    }
  }

  void _toran(Canvas canvas, Size size) {
    final w = size.width;
    double sag(double t) => 10 + 14 * 4 * t * (1 - t);
    canvas.drawPath(
      Path()
        ..moveTo(0, 10)
        ..quadraticBezierTo(w / 2, 38, w, 10),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    const n = 13;
    for (var i = 0; i < n; i++) {
      final t = (i + 0.5) / n;
      final top = Offset(w * t, sag(t));
      if (i.isEven) {
        final tip = top + const Offset(0, 36);
        final leaf = Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(top.dx + 11, top.dy + 14, tip.dx, tip.dy)
          ..quadraticBezierTo(top.dx - 11, top.dy + 14, top.dx, top.dy);
        canvas.drawPath(
          leaf,
          Paint()
            ..shader = const LinearGradient(
              colors: [_leaf, _leafLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromPoints(top, tip + const Offset(12, 0))),
        );
        canvas.drawLine(
          top,
          tip - const Offset(0, 6),
          Paint()
            ..color = const Color(0xFF1B5E20)
            ..strokeWidth = 1,
        );
      } else {
        for (var k = 0; k < 3; k++) {
          final c = top + Offset(0, 7 + k * 11.0);
          canvas.drawCircle(c, 6.5 - k * 0.6, Paint()..color = k.isEven ? _marigold : _marigoldLight);
          canvas.drawCircle(c, 2, Paint()..color = const Color(0xFFBF360C));
        }
      }
    }
  }

  void _bunting(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawPath(
      Path()
        ..moveTo(0, 12)
        ..quadraticBezierTo(w / 2, 36, w, 12),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    const n = 11;
    for (var i = 0; i < n; i++) {
      final t0 = i / n + 0.01, t1 = (i + 1) / n - 0.01;
      double y(double t) => 12 + 12 * 4 * t * (1 - t);
      final a = Offset(w * t0, y(t0)), b = Offset(w * t1, y(t1));
      final tip = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + 24);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(tip.dx, tip.dy)
          ..close(),
        Paint()..color = i.isEven ? const Color(0xFFFF6F00) : Color.lerp(accent, Colors.white, 0.3)!,
      );
    }
  }

  void _kite(Canvas canvas, Offset c, double s, Color body, Color trim, double tilt) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    final kite = Path()
      ..moveTo(0, -s)
      ..lineTo(s * 0.8, 0)
      ..lineTo(0, s * 1.1)
      ..lineTo(-s * 0.8, 0)
      ..close();
    canvas.drawPath(kite, Paint()..color = body);
    canvas.drawPath(
      Path()
        ..moveTo(0, -s)
        ..lineTo(s * 0.8, 0)
        ..lineTo(0, 0)
        ..close(),
      Paint()..color = trim.withValues(alpha: 0.8),
    );
    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(Offset(0, -s), Offset(0, s * 1.1), line)
      ..drawLine(Offset(-s * 0.8, 0), Offset(s * 0.8, 0), line);
    final tail = Path()..moveTo(0, s * 1.1);
    for (var i = 1; i <= 3; i++) {
      tail.quadraticBezierTo(i.isEven ? -8 : 8, s * 1.1 + i * 9 - 4, 0, s * 1.1 + i * 9);
    }
    canvas.drawPath(
      tail,
      line
        ..color = body
        ..strokeWidth = 1.6,
    );
    for (var i = 1; i <= 2; i++) {
      final y = s * 1.1 + i * 16;
      canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..lineTo(-6, y - 4)
          ..lineTo(-6, y + 4)
          ..close()
          ..moveTo(0, y)
          ..lineTo(6, y - 4)
          ..lineTo(6, y + 4)
          ..close(),
        Paint()..color = trim,
      );
    }
    canvas.restore();
  }

  void _bell(Canvas canvas, Offset top, double drop, double s) {
    final chain = Paint()
      ..color = accent
      ..strokeWidth = 1.6;
    for (var y = 0.0; y < drop; y += 6) {
      canvas.drawOval(Rect.fromCenter(center: top + Offset(0, y + 3), width: 3.5, height: 5.5), chain);
    }
    canvas.save();
    canvas.translate(top.dx, top.dy + drop);
    canvas.scale(s);
    final body = Path()
      ..moveTo(-6, 4)
      ..cubicTo(-14, 6, -13, 26, -22, 38)
      ..lineTo(22, 38)
      ..cubicTo(13, 26, 14, 6, 6, 4)
      ..close();
    canvas.drawCircle(const Offset(0, 2), 5, Paint()..color = accent);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(accent, Colors.white, 0.35)!, accent, Color.lerp(accent, Colors.black, 0.35)!],
        ).createShader(const Rect.fromLTRB(-22, 0, 22, 38)),
    );
    canvas.drawRect(const Rect.fromLTRB(-23, 36, 23, 40), Paint()..color = Color.lerp(accent, Colors.black, 0.3)!);
    canvas.drawCircle(const Offset(0, 44), 4, Paint()..color = Color.lerp(accent, Colors.black, 0.4)!);
    canvas.restore();
  }

  void _feather(Canvas canvas, Offset from, Offset eye) {
    final d = eye - from;
    final angle = math.atan2(d.dy, d.dx);
    final length = d.distance;
    canvas.save();
    canvas.translate(from.dx, from.dy);
    canvas.rotate(angle);
    final barb = Paint()
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    for (var x = 8.0; x < length + 26; x += 3.2) {
      final spread = 8 + 26 * math.sin(math.min(1.0, x / (length + 26)) * math.pi * 0.95);
      barb.color = Color.lerp(const Color(0xFF00695C), const Color(0xFF9CCC65), x / length)!.withValues(alpha: 0.75);
      canvas
        ..drawLine(Offset(x, 0), Offset(x + 10, -spread), barb)
        ..drawLine(Offset(x, 0), Offset(x + 10, spread), barb);
    }
    canvas.drawLine(
      Offset.zero,
      Offset(length + 30, 0),
      Paint()
        ..color = const Color(0xFFF5E6C8)
        ..strokeWidth = 1.6,
    );
    final c = Offset(length, 0);
    for (final (rx, ry, color) in [
      (30.0, 22.0, const Color(0xFFC0CA33)),
      (24.0, 17.0, const Color(0xFF00897B)),
      (17.0, 12.0, const Color(0xFFB8860B)),
      (12.0, 9.0, const Color(0xFF1565C0)),
      (7.0, 6.0, const Color(0xFF0D1B4C)),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: c + Offset(rx * 0.15, 0), width: rx * 2, height: ry * 2),
        Paint()..color = color,
      );
    }
    canvas.restore();
  }

  void _diya(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c + Offset(0, -r * 1.2),
      r * 1.9,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFE082).withValues(alpha: 0.65), const Color(0xFFFFE082).withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c + Offset(0, -r * 1.2), radius: r * 1.9)),
    );
    final bowl = Path()
      ..moveTo(c.dx - r * 1.2, c.dy - r * 0.15)
      ..quadraticBezierTo(c.dx, c.dy + r * 1.2, c.dx + r * 1.2, c.dy - r * 0.15)
      ..quadraticBezierTo(c.dx + r * 1.55, c.dy - r * 0.45, c.dx + r * 1.7, c.dy - r * 0.55)
      ..quadraticBezierTo(c.dx + r * 0.9, c.dy + r * 0.05, c.dx, c.dy + r * 0.05)
      ..quadraticBezierTo(c.dx - r * 0.9, c.dy + r * 0.05, c.dx - r * 1.2, c.dy - r * 0.15)
      ..close();
    canvas.drawPath(
      bowl,
      Paint()
        ..shader = const LinearGradient(
          colors: [_clay, _clayDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromCenter(center: c, width: r * 3, height: r * 1.4)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 1.2, c.dy - r * 0.15)
        ..quadraticBezierTo(c.dx, c.dy + r * 0.25, c.dx + r * 1.2, c.dy - r * 0.15),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final f = Offset(c.dx + r * 1.4, c.dy - r * 0.6);
    final flame = Path()
      ..moveTo(f.dx, f.dy - r * 1.5)
      ..quadraticBezierTo(f.dx + r * 0.55, f.dy - r * 0.45, f.dx, f.dy)
      ..quadraticBezierTo(f.dx - r * 0.55, f.dy - r * 0.45, f.dx, f.dy - r * 1.5);
    canvas.drawPath(
      flame,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFCA28), Color(0xFFFF6F00)],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(Rect.fromLTRB(f.dx - r, f.dy - r * 1.5, f.dx + r, f.dy)),
    );
  }

  void _rangoli(Canvas canvas, Offset c, double radius) {
    const rings = [Color(0xFFE91E63), Color(0xFFFF9800), Color(0xFFFFEB3B), Color(0xFF43A047), Color(0xFF1E88E5)];
    canvas.drawCircle(c, radius, Paint()..color = Colors.white.withValues(alpha: 0.85));
    for (var k = 0; k < rings.length; k++) {
      final r0 = radius * (1 - k * 0.18), n = 16 - k * 2;
      for (var i = 0; i < n; i++) {
        final a = math.pi + i * 2 * math.pi / n;
        final p0 = c + Offset(math.cos(a), math.sin(a)) * r0 * 0.55;
        final p1 = c + Offset(math.cos(a), math.sin(a)) * r0 * 0.97;
        final side = Offset(-math.sin(a), math.cos(a)) * r0 * 0.12;
        final mid = Offset.lerp(p0, p1, 0.5)!;
        canvas.drawPath(
          Path()
            ..moveTo(p0.dx, p0.dy)
            ..quadraticBezierTo((mid + side).dx, (mid + side).dy, p1.dx, p1.dy)
            ..quadraticBezierTo((mid - side).dx, (mid - side).dy, p0.dx, p0.dy),
          Paint()..color = rings[k],
        );
      }
    }
    canvas.drawCircle(c, radius * 0.22, Paint()..color = accent);
    final dot = Paint()..color = accent;
    for (var i = 0; i < 36; i++) {
      final a = i * 2 * math.pi / 36;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (radius + 8), 2.6, dot);
    }
  }

  void _lotus(Canvas canvas, Offset base, double s) {
    final pad = Paint()..color = const Color(0xFF388E3C);
    canvas.drawOval(Rect.fromCenter(center: base + Offset(-70 * s, 6), width: 110 * s, height: 26 * s), pad);
    canvas.drawOval(Rect.fromCenter(center: base + Offset(70 * s, 6), width: 110 * s, height: 26 * s), pad);
    void petal(double angle, double length, double width, Color a, Color b) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(width, -length * 0.5, 0, -length)
        ..quadraticBezierTo(-width, -length * 0.5, 0, 0);
      canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            colors: [a, b],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ).createShader(Rect.fromLTRB(-width, -length, width, 0)),
      );
      canvas.drawPath(
        p,
        Paint()
          ..color = accent.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.restore();
    }

    const deep = Color(0xFFD81B60), pale = Color(0xFFFCE4EC);
    for (final a in [-1.25, 1.25]) {
      petal(a, 64 * s, 22 * s, deep, pale);
    }
    for (final a in [-0.75, 0.75]) {
      petal(a, 76 * s, 24 * s, deep, pale);
    }
    for (final a in [-0.32, 0.32]) {
      petal(a, 86 * s, 24 * s, deep, pale);
    }
    petal(0, 92 * s, 24 * s, deep, Colors.white);
  }

  void _pot(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height);
    canvas.scale(0.72);
    canvas.translate(-size.width / 2, -size.height);
    final c = Offset(size.width / 2, size.height - 48);
    for (final dx in [-200.0, 200.0]) {
      final x = c.dx + dx;
      final cane = Paint()
        ..color = const Color(0xFF6A1B4D)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, size.height), Offset(x - dx * 0.12, size.height - 110), cane);
      for (var k = 1; k < 6; k++) {
        final p = Offset.lerp(Offset(x, size.height), Offset(x - dx * 0.12, size.height - 110), k / 6)!;
        canvas.drawLine(
          p - const Offset(4, 0),
          p + const Offset(4, 0),
          Paint()
            ..color = const Color(0xFFD7CCC8)
            ..strokeWidth = 1.4,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(x - dx * 0.12, size.height - 110)
          ..quadraticBezierTo(x - dx * 0.3, size.height - 140, x - dx * 0.38, size.height - 124),
        Paint()
          ..color = _leafLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
    canvas.drawCircle(
      c,
      44,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFD9773A), _clay, _clayDark],
          center: Alignment(-0.3, -0.4),
        ).createShader(Rect.fromCircle(center: c, radius: 44)),
    );
    canvas.drawRect(
      Rect.fromCenter(center: c + const Offset(0, -42), width: 46, height: 12),
      Paint()..color = _clayDark,
    );
    canvas.drawRect(Rect.fromCenter(center: c, width: 86, height: 8), Paint()..color = accent);
    final foam = Paint()..color = const Color(0xFFFFFDE7);
    for (final (dx, dy, r) in [(-18.0, -52.0, 11.0), (-4.0, -58.0, 13.0), (12.0, -54.0, 12.0), (24.0, -46.0, 8.0)]) {
      canvas.drawCircle(c + Offset(dx, dy), r, foam);
    }
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 22, c.dy - 44)
        ..quadraticBezierTo(c.dx + 30, c.dy - 24, c.dx + 26, c.dy - 10)
        ..quadraticBezierTo(c.dx + 20, c.dy - 22, c.dx + 16, c.dy - 42),
      foam,
    );
    canvas.restore();
  }

  void _kolam(Canvas canvas, Size size) {
    final dot = Paint()..color = accent;
    final line = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const gap = 22.0;
    const cols = 13;
    final left = (size.width - (cols - 1) * gap) / 2;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < cols; col++) {
        if ((row + col).isOdd) continue;
        final c = Offset(left + col * gap, size.height - 22 - row * gap);
        canvas.drawCircle(c, 2.4, dot);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(math.pi / 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 22, height: 22),
            const Radius.circular(8),
          ),
          line,
        );
        canvas.restore();
      }
    }
  }

  void _rakhi(Canvas canvas, Size size) {
    final y = size.height - 42;
    final w = size.width;
    for (final (phase, color) in [(0.0, const Color(0xFFC62828)), (math.pi, const Color(0xFFFFC107))]) {
      final p = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w; x += 4) {
        p.lineTo(x, y + math.sin(x / 7 + phase) * 2.5);
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }
    final c = Offset(w / 2, y);
    canvas.drawCircle(c, 40, Paint()..color = const Color(0xFFC62828));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawOval(
        Rect.fromCenter(center: c + Offset(math.cos(a), math.sin(a)) * 26, width: 16, height: 16),
        Paint()..color = i.isEven ? _marigoldLight : const Color(0xFFFF7043),
      );
    }
    canvas.drawCircle(c, 17, Paint()..color = accent);
    canvas.drawCircle(c, 9, Paint()..color = Colors.white);
    final pearl = Paint()..color = Colors.white;
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * 42, 2.4, pearl);
    }
    for (final x in [w * 0.12, w * 0.88]) {
      canvas.drawCircle(Offset(x, y), 7, Paint()..color = _marigoldLight);
    }
  }

  void _garland(Canvas canvas, Size size) {
    final w = size.width;
    final top = size.height - 74;
    const swags = 3;
    for (var s = 0; s < swags; s++) {
      final x0 = w * s / swags, x1 = w * (s + 1) / swags;
      for (var i = 0; i <= 12; i++) {
        final t = i / 12;
        final p = Offset(x0 + (x1 - x0) * t, top + 34 * 4 * t * (1 - t));
        canvas.drawCircle(p, 7.5, Paint()..color = i.isEven ? _marigold : _marigoldLight);
        canvas.drawCircle(p, 2.2, Paint()..color = const Color(0xFFBF360C));
      }
      final hang = Offset(x0, top);
      if (s > 0) {
        for (var k = 0; k < 3; k++) {
          canvas.drawCircle(hang + Offset(0, 10 + k * 12.0), 6, Paint()..color = k.isEven ? _marigold : _marigoldLight);
        }
        canvas.drawCircle(hang + const Offset(0, 48), 4, Paint()..color = accent);
      }
    }
  }

  @override
  bool shouldRepaint(WishMotifPainter old) => old.top != top || old.bottom != bottom || old.accent != accent;
}

void _sparkle(Canvas canvas, Offset c, double r, Color color) {
  final p = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
  canvas.drawPath(p, Paint()..color = color);
  canvas.drawCircle(
    c,
    r * 0.9,
    Paint()
      ..color = color.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
  );
}

/// A short ornamental rule: a line, a diamond, a line.
class OrnamentPainter extends CustomPainter {
  OrnamentPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final line = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.4;
    canvas
      ..drawLine(Offset(0, c.dy), Offset(c.dx - 14, c.dy), line)
      ..drawLine(Offset(c.dx + 14, c.dy), Offset(size.width, c.dy), line)
      ..drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 7)
          ..lineTo(c.dx + 9, c.dy)
          ..lineTo(c.dx, c.dy + 7)
          ..lineTo(c.dx - 9, c.dy)
          ..close(),
        Paint()..color = color,
      )
      ..drawCircle(Offset(c.dx - 22, c.dy), 2.5, Paint()..color = color)
      ..drawCircle(Offset(c.dx + 22, c.dy), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(OrnamentPainter old) => old.color != color;
}
