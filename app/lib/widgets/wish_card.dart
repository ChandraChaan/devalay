import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/wishes.dart';
import 'common.dart';
import 'wish_art.dart';

/// Everything a wish card shows. The card itself only draws; the editor owns the state.
@immutable
class WishCardData {
  const WishCardData({
    required this.theme,
    required this.layout,
    required this.caption,
    this.message = '',
    this.name = '',
    this.line2 = '',
    this.fromLabel = '',
    this.photo,
    this.view = PhotoView.initial,
    this.painting,
    this.symbol = 'ॐ',
  });

  final WishTheme theme;
  final WishLayout layout;
  final String caption, message, name, line2;

  /// Shown above the name, such as "With best wishes".
  final String fromLabel;

  /// The sender's photo, read from a file on this phone.
  final ImageProvider? photo;
  final PhotoView view;

  /// A public-domain painting of the deity; without one the card draws [symbol].
  final String? painting;
  final String symbol;
}

/// A 9:16 greeting card. It is laid out on a fixed 360×640 canvas and scaled to fit, so the preview,
/// the thumbnails and the exported 1080×1920 image are the same picture.
class WishCard extends StatelessWidget {
  const WishCard(this.data, {super.key, this.onView, this.onViewEnd});

  static const width = 360.0, height = 640.0;

  final WishCardData data;

  /// When set, the photo can be dragged and pinched inside its frame.
  final ValueChanged<PhotoView>? onView;
  final VoidCallback? onViewEnd;

  WishTheme get _t => data.theme;
  bool get _hasPhoto => data.photo != null;
  bool get _hasPainting => data.painting != null && data.painting!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final children = switch (data.layout) {
      WishLayout.darshan => _darshan(),
      WishLayout.banner => _banner(),
      WishLayout.badge => _badge(),
      WishLayout.split => _split(),
      WishLayout.portrait => _portrait(),
      WishLayout.text => _text(),
    };
    return FittedBox(
      child: SizedBox(
        width: width,
        height: height,
        // Material gives the card's text a style of its own wherever the card is shown.
        child: Material(
          type: MaterialType.transparency,
          // The card is a picture: the phone's font size setting must not move its text.
          child: MediaQuery.withNoTextScaling(
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _t.colors,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  if (_t.backdrop.isNotEmpty)
                    Positioned.fill(child: CustomPaint(painter: WishBackdropPainter(_t.backdrop, _t.accent))),
                  ...children,
                  const Positioned(
                    right: 10,
                    bottom: 5,
                    child: Text(
                      'Devalay',
                      style: TextStyle(
                        fontFamily: 'Mukta',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xB3FFFFFF),
                        shadows: [Shadow(blurRadius: 4, color: Color(0x99000000))],
                      ),
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

  // Layouts. The top 62 points belong to the top decoration and the bottom 76 to the bottom one.

  /// Caption above, the deity in an arch and the sender's photo in a round frame at its side.
  List<Widget> _darshan() => [
    _motifs(),
    _caption(top: 66, height: 80, size: 46),
    if (_hasPhoto) ...[
      Positioned(left: 40, top: 152, child: _art(_Shape.arch, const Size(186, 240))),
      Positioned(left: 186, top: 300, child: _photo(_Shape.circle, const Size(134, 134))),
    ] else
      Positioned(left: 78, top: 152, child: _art(_Shape.arch, const Size(204, 262))),
    Positioned(left: 24, right: 24, top: _hasPhoto ? 442 : 424, bottom: 74, child: _words()),
  ];

  /// The painting across the top, fading into the card, with a ribbon carrying the photo and name.
  List<Widget> _banner() {
    final bandText = _t.accent.computeLuminance() > 0.4 ? Palette.ink : Colors.white;
    return [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: 430,
        child: _hasPainting
            ? ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0, 0.6, 1],
                ).createShader(r),
                child: NetImage(data.painting!, alignment: Alignment.topCenter),
              )
            : Align(alignment: const Alignment(0, -0.2), child: _art(_Shape.circle, const Size(210, 210))),
      ),
      _motifs(),
      _caption(top: 334, height: 86, size: 44),
      Positioned(left: 24, right: 24, top: 420, height: 56, child: _message(size: 16)),
      Positioned(
        left: 0,
        right: 0,
        top: 484,
        height: 78,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_t.accent, Color.lerp(_t.accent, Colors.black, 0.25)!]),
            border: const Border.symmetric(horizontal: BorderSide(color: Color(0x99FFFFFF), width: 2)),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
        ),
      ),
      if (_hasPhoto) ...[
        Positioned(left: 16, top: 467, child: _photo(_Shape.circle, const Size(112, 112))),
        Positioned(
          left: 142,
          right: 16,
          top: 488,
          height: 70,
          child: _signature(color: bandText, labelColor: bandText, align: TextAlign.left, width: 202, nameSize: 26),
        ),
      ] else
        Positioned(
          left: 24,
          right: 24,
          top: 488,
          height: 70,
          child: _signature(color: bandText, labelColor: bandText, nameSize: 28),
        ),
    ];
  }

  /// The painting fills the card, the words sit on a dark scrim and the photo is a small badge.
  List<Widget> _badge() {
    final onArt = _hasPainting;
    final caption = onArt && _t.accent.computeLuminance() < 0.35 ? Colors.white : _t.accent;
    final text = onArt ? Colors.white : _t.ink;
    final name = onArt ? caption : _t.accent;
    return [
      if (onArt) ...[
        Positioned.fill(child: NetImage(data.painting!, alignment: Alignment.topCenter)),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0xD9000000)],
                stops: [0, 0.16, 0.48, 0.8],
              ),
            ),
          ),
        ),
      ] else
        Positioned(left: 60, top: 108, child: _art(_Shape.circle, const Size(240, 240))),
      _motifs(bottom: false),
      _caption(top: 386, height: 96, size: 50, color: caption),
      Positioned(left: 24, right: 24, top: 482, height: 56, child: _message(size: 16, color: text)),
      if (_hasPhoto) ...[
        Positioned(left: 22, top: 546, child: _photo(_Shape.circle, const Size(80, 80))),
        Positioned(
          left: 116,
          right: 20,
          top: 548,
          height: 76,
          child: _signature(color: name, align: TextAlign.left, width: 224, labelColor: text),
        ),
      ] else
        Positioned(
          left: 24,
          right: 24,
          top: 548,
          height: 76,
          child: _signature(color: name, labelColor: text),
        ),
    ];
  }

  /// The painting on top under a curved edge; the caption, photo and name below it.
  List<Widget> _split() => [
    Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 330,
      child: ClipPath(
        clipper: _CurveClipper(),
        child: _hasPainting
            ? NetImage(data.painting!, alignment: Alignment.topCenter)
            : _SymbolFill(symbol: data.symbol, theme: _t, size: 150),
      ),
    ),
    Positioned(left: 0, right: 0, top: 0, height: 330, child: CustomPaint(painter: _CurveEdgePainter(_t.accent))),
    _motifs(),
    _caption(top: 334, height: 80, size: 42),
    if (_hasPhoto) ...[
      Positioned(left: 24, top: 424, child: _photo(_Shape.rounded, const Size(126, 126))),
      Positioned(left: 166, right: 22, top: 420, bottom: 88, child: _words(align: TextAlign.left, width: 172)),
    ] else
      Positioned(left: 24, right: 24, top: 418, bottom: 76, child: _words()),
  ];

  /// The sender's photo is the centre of the card, with the deity's blessing above it.
  List<Widget> _portrait() => _hasPhoto
      ? [
          _motifs(),
          Positioned(left: 138, top: 64, child: _art(_Shape.circle, const Size(84, 84))),
          _caption(top: 150, height: 68, size: 38),
          Positioned(left: 90, top: 224, child: _photo(_Shape.arch, const Size(180, 222))),
          Positioned(left: 24, right: 24, top: 452, bottom: 74, child: _words(messageSize: 16, nameSize: 25)),
        ]
      : [
          Positioned(
            left: 40,
            top: 128,
            child: CustomPaint(size: const Size(280, 280), painter: _HaloPainter(_t.accent)),
          ),
          _motifs(),
          _caption(top: 66, height: 80, size: 44),
          Positioned(left: 70, top: 158, child: _art(_Shape.circle, const Size(220, 220))),
          Positioned(left: 24, right: 24, top: 420, bottom: 76, child: _words()),
        ];

  /// Words first: the sacred syllable, a large caption and the wish, with no painting.
  List<Widget> _text() => [
    _motifs(),
    Positioned(
      left: 0,
      right: 0,
      top: 64,
      height: 64,
      child: Center(child: Text(data.symbol, style: _style(50, _t.accent, serif: true, height: 1.3))),
    ),
    Positioned(left: 96, right: 96, top: 132, height: 16, child: CustomPaint(painter: OrnamentPainter(_t.accent))),
    _caption(top: 152, height: 150, size: 62),
    Positioned(left: 96, right: 96, top: 306, height: 16, child: CustomPaint(painter: OrnamentPainter(_t.accent))),
    Positioned(left: 28, right: 28, top: 328, height: _hasPhoto ? 84 : 104, child: _message(size: 21, width: 304)),
    if (_hasPhoto) ...[
      Positioned(left: 134, top: 420, child: _photo(_Shape.circle, const Size(92, 92))),
      Positioned(left: 24, right: 24, top: 516, bottom: 76, child: _signature(nameSize: 24)),
    ] else
      Positioned(left: 24, right: 24, top: 440, bottom: 80, child: _signature(nameSize: 28)),
  ];

  // Pieces.

  Widget _motifs({bool top = true, bool bottom = true}) => Positioned.fill(
    child: IgnorePointer(
      child: CustomPaint(
        painter: WishMotifPainter(top: top ? _t.top : '', bottom: bottom ? _t.bottom : '', accent: _t.accent),
      ),
    ),
  );

  TextStyle _style(double size, Color color, {bool serif = false, FontWeight? weight, double height = 1.25}) =>
      TextStyle(
        fontFamily: serif ? scriptureFont : 'Mukta',
        fontFamilyFallback: serif ? scriptureFontFallback : uiFontFallback,
        fontSize: size,
        height: height,
        fontWeight: weight ?? (serif ? FontWeight.w400 : FontWeight.w600),
        color: color,
        shadows: color.computeLuminance() > 0.5
            ? const [Shadow(blurRadius: 10, color: Color(0x99000000))]
            : const [Shadow(blurRadius: 8, color: Color(0x55FFFFFF))],
      );

  Widget _caption({required double top, required double height, required double size, Color? color}) => Positioned(
    left: 20,
    right: 20,
    top: top,
    height: height,
    child: _Fit(
      data.caption,
      _style(
        size,
        color ?? _t.accent,
        serif: _t.serif,
        weight: _t.serif ? FontWeight.w400 : FontWeight.w800,
        height: 1.12,
      ),
      width: 320,
    ),
  );

  Widget _message({double size = 17, Color? color, double width = 312, TextAlign align = TextAlign.center}) =>
      _Fit(data.message, _style(size, color ?? _t.ink, height: 1.35), width: width, align: align);

  Widget _signature({
    Color? color,
    Color? labelColor,
    TextAlign align = TextAlign.center,
    double width = 312,
    double nameSize = 26,
  }) {
    final c = color ?? _t.accent;
    final label = labelColor ?? _t.ink;
    if (data.name.isEmpty && data.line2.isEmpty) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: align == TextAlign.left ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (data.name.isNotEmpty && data.fromLabel.isNotEmpty)
              Text(data.fromLabel, textAlign: align, style: _style(13, label.withValues(alpha: 0.85))),
            if (data.name.isNotEmpty)
              Text(
                data.name,
                textAlign: align,
                style: _style(nameSize, c, weight: FontWeight.w700, height: 1.15),
              ),
            if (data.line2.isNotEmpty)
              Text(data.line2, textAlign: align, style: _style(nameSize * 0.58, label.withValues(alpha: 0.92))),
          ],
        ),
      ),
    );
  }

  /// The wish and the signature, sharing the space between them.
  Widget _words({
    TextAlign align = TextAlign.center,
    double width = 312,
    double messageSize = 17,
    double nameSize = 26,
  }) {
    final message = data.message.isNotEmpty;
    final signed = data.name.isNotEmpty || data.line2.isNotEmpty;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: align == TextAlign.left ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // The name keeps its size; the wish shrinks if the two do not fit.
        if (message)
          Flexible(
            child: _message(size: messageSize, width: width, align: align),
          ),
        if (message && signed) const SizedBox(height: 8),
        if (signed) _signature(align: align, width: width, nameSize: nameSize),
      ],
    );
  }

  Widget _art(_Shape shape, Size size) => _Framed(
    shape: shape,
    size: size,
    color: _t.accent,
    child: _hasPainting
        ? NetImage(data.painting!, alignment: Alignment.topCenter)
        : _SymbolFill(symbol: data.symbol, theme: _t, size: size.shortestSide * 0.42),
  );

  Widget _photo(_Shape shape, Size size) => _Framed(
    shape: shape,
    size: size,
    color: _t.accent,
    child: _PhotoArea(photo: data.photo!, view: data.view, size: size, onView: onView, onViewEnd: onViewEnd),
  );
}

/// Text scaled down to fit its box, wrapping at [width].
class _Fit extends StatelessWidget {
  const _Fit(this.text, this.style, {this.width = 312, this.align = TextAlign.center});
  final String text;
  final TextStyle style;
  final double width;
  final TextAlign align;

  /// Smaller type when one word is wider than the line, so a long Telugu or Hindi word shrinks
  /// instead of breaking in the middle.
  TextStyle get _fitted {
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest > width ? style.copyWith(fontSize: style.fontSize! * width / widest * 0.97) : style;
  }

  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
          child: SizedBox(
            width: width,
            child: Text(text, textAlign: align, style: _fitted),
          ),
        );
}

enum _Shape { circle, arch, rounded }

Path _shapePath(_Shape shape, Size size) {
  final r = Offset.zero & size;
  return switch (shape) {
    _Shape.circle => Path()..addOval(r),
    _Shape.arch =>
      Path()..addRRect(
        RRect.fromRectAndCorners(
          r,
          topLeft: Radius.circular(size.width / 2),
          topRight: Radius.circular(size.width / 2),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
      ),
    _Shape.rounded => Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(22))),
  };
}

class _ShapeClipper extends CustomClipper<Path> {
  _ShapeClipper(this.shape);
  final _Shape shape;
  @override
  Path getClip(Size size) => _shapePath(shape, size);
  @override
  bool shouldReclip(_ShapeClipper old) => old.shape != shape;
}

/// A shadow under the frame, or the gold ring around it.
class _FramePainter extends CustomPainter {
  _FramePainter(this.shape, this.color, {required this.ring});
  final _Shape shape;
  final Color color;
  final bool ring;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shapePath(shape, size);
    if (!ring) {
      canvas.drawShadow(path, Colors.black, 10, false);
      return;
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      )
      ..drawPath(
        _shapePath(shape, Size(size.width - 14, size.height - 14)).shift(const Offset(7, 7)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.shape != shape || old.color != color || old.ring != ring;
}

class _Framed extends StatelessWidget {
  const _Framed({required this.shape, required this.size, required this.color, required this.child});
  final _Shape shape;
  final Size size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _FramePainter(shape, color, ring: false)),
        ClipPath(clipper: _ShapeClipper(shape), child: child),
        IgnorePointer(child: CustomPaint(painter: _FramePainter(shape, color, ring: true))),
      ],
    ),
  );
}

/// The deity's syllable on a deep ground, used when there is no painting.
class _SymbolFill extends StatelessWidget {
  const _SymbolFill({required this.symbol, required this.theme, required this.size});
  final String symbol;
  final WishTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = theme.colors.last;
    final glyph = theme.accent.computeLuminance() > 0.35 ? theme.accent : Palette.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [Color.lerp(base, Colors.black, 0.3)!, Color.lerp(base, Colors.black, 0.7)!]),
      ),
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontFamily: scriptureFont,
            fontFamilyFallback: scriptureFontFallback,
            fontSize: size,
            height: 1.3,
            color: glyph,
            shadows: [Shadow(blurRadius: 24, color: glyph.withValues(alpha: 0.8))],
          ),
        ),
      ),
    );
  }
}

/// The user's photo, zoomed and positioned as they left it.
class _PhotoArea extends StatefulWidget {
  const _PhotoArea({required this.photo, required this.view, required this.size, this.onView, this.onViewEnd});
  final ImageProvider photo;
  final PhotoView view;
  final Size size;
  final ValueChanged<PhotoView>? onView;
  final VoidCallback? onViewEnd;

  @override
  State<_PhotoArea> createState() => _PhotoAreaState();
}

class _PhotoAreaState extends State<_PhotoArea> {
  PhotoView _start = PhotoView.initial;
  Offset _focal = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final focus = Alignment(v.x, v.y);
    final image = Transform.scale(
      scale: v.scale,
      alignment: focus,
      child: Image(
        image: widget.photo,
        fit: BoxFit.cover,
        alignment: focus,
        width: widget.size.width,
        height: widget.size.height,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0x33000000)),
      ),
    );
    final onView = widget.onView;
    if (onView == null) return image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _start = widget.view;
        _focal = d.localFocalPoint;
      },
      onScaleUpdate: (d) {
        final scale = (_start.scale * d.scale).clamp(1.0, PhotoView.maxScale);
        final delta = d.localFocalPoint - _focal;
        onView(
          _start.copyWith(
            scale: scale,
            x: _start.x - delta.dx / (widget.size.width / 2) / scale,
            y: _start.y - delta.dy / (widget.size.height / 2) / scale,
          ),
        );
      },
      onScaleEnd: (_) => widget.onViewEnd?.call(),
      child: image,
    );
  }
}

Path _curve(Size size) => Path()
  ..moveTo(0, 0)
  ..lineTo(size.width, 0)
  ..lineTo(size.width, size.height - 44)
  ..quadraticBezierTo(size.width / 2, size.height + 30, 0, size.height - 44)
  ..close();

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _curve(size);
  @override
  bool shouldReclip(_CurveClipper old) => false;
}

class _CurveEdgePainter extends CustomPainter {
  _CurveEdgePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = Path()
      ..moveTo(0, size.height - 44)
      ..quadraticBezierTo(size.width / 2, size.height + 30, size.width, size.height - 44);
    canvas
      ..drawPath(
        edge,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawPath(
        edge,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
  }

  @override
  bool shouldRepaint(_CurveEdgePainter old) => old.color != color;
}

/// A ring of light behind a deity in a round frame.
class _HaloPainter extends CustomPainter {
  _HaloPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final dot = Paint()..color = color;
    for (var i = 0; i < 48; i++) {
      final a = i * 3.14159265 * 2 / 48;
      canvas.drawCircle(c + Offset.fromDirection(a, r * 0.9), i.isEven ? 2.6 : 1.4, dot);
    }
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.color != color;
}
