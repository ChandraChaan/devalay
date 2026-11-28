import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/sections.dart';
import '../core/status_library.dart';
import '../core/theme.dart';
import 'common.dart';
import 'mandala.dart';

/// The designs AI Status draws a status on. Each lays out at 360×640 logical pixels and is exported at
/// 1080×1920 (pixel ratio 3). The five with a [premiumRank] are the Premium collection.
enum StatusTemplate {
  swarna('Swarna', 'स्वर्ण', 'స్వర్ణ', 1),
  gopuram('Gopuram', 'गोपुरम', 'గోపురం', 2),
  pattu('Pattu silk', 'रेशमी', 'పట్టు', 3),
  padma('Padma', 'पद्म', 'పద్మం', 4),
  rajasa('Royal art', 'राजसी चित्र', 'రాజస చిత్రం', 5),
  photo('Photo', 'फ़ोटो', 'ఫోటో', null),
  neon('Neon', 'नियॉन', 'నియాన్', null),
  aurora('Aurora', 'ऑरोरा', 'అరోరా', null),
  glass('Glass', 'ग्लास', 'గ్లాస్', null),
  deepam('Deepam', 'दीपम्', 'దీపం', null),
  art('Art', 'चित्र', 'చిత్రం', null),
  kumkum('Kumkum', 'कुमकुम', 'కుంకుమ', null),
  chandan('Chandan', 'चंदन', 'చందనం', null),
  neelam('Night sky', 'तारों भरा आकाश', 'నక్షత్ర ఆకాశం', null),
  tulasi('Tulasi', 'तुलसी', 'తులసి', null),
  minimal('Minimal', 'सादा', 'సాదా', null);

  const StatusTemplate(this.en, this.hi, this.te, this.premiumRank);
  final String en, hi, te;
  final int? premiumRank;
  bool get isPremium => premiumRank != null;
  bool get usesArt => const {art, gopuram, rajasa, photo, glass}.contains(this);

  /// The art designs that look best on a recent photograph or a modern design rather than a painting.
  bool get prefersPhoto => const {rajasa, photo, glass}.contains(this);

  String label(String lang) => switch (lang) {
    'te' => te,
    'hi' => hi,
    _ => en,
  };
}

/// One status, drawn on [template]. [artUrl] is the deity's wallpaper for the art designs.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.content, required this.template, this.artUrl});
  final StatusContent content;
  final StatusTemplate template;
  final String? artUrl;

  static const size = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          // A fixed design: the phone's text size setting must not reflow an exported picture.
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: ClipRect(child: _build()),
        ),
      ),
    );
  }

  Widget _build() => switch (template) {
    StatusTemplate.swarna => _Swarna(content),
    StatusTemplate.gopuram => _Gopuram(content, artUrl),
    StatusTemplate.pattu => _Pattu(content),
    StatusTemplate.padma => _Padma(content),
    StatusTemplate.rajasa => _Rajasa(content, artUrl),
    StatusTemplate.deepam => _Plain(
      content,
      background: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.1,
          colors: [Color(0xFF7A2410), Color(0xFF3A0D05), Color(0xFF140402)],
        ),
      ),
      mandala: Palette.gold,
    ),
    StatusTemplate.art => _ArtFull(content, artUrl),
    StatusTemplate.photo => _ArtFull(content, artUrl),
    StatusTemplate.neon => _Neon(content),
    StatusTemplate.aurora => _Aurora(content),
    StatusTemplate.glass => _Glass(content, artUrl),
    StatusTemplate.kumkum => _Plain(
      content,
      background: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8F00), Color(0xFFD84315), Color(0xFF8E0E0E)],
        ),
      ),
      mandala: Colors.white,
      bottom: const _DotBand(color: Color(0xFFFFE0B2)),
      headline: Colors.white,
    ),
    StatusTemplate.chandan => _Plain(
      content,
      background: const BoxDecoration(color: Color(0xFFFFF1DC)),
      mandala: const Color(0xFFB0652B),
      ink: const Color(0xFF4A1A08),
      headline: const Color(0xFF8E1B0B),
      frame: const Color(0xFF8E1B0B),
    ),
    StatusTemplate.neelam => _Plain(
      content,
      background: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060B26), Color(0xFF16215C), Color(0xFF2B1A55)],
        ),
      ),
      stars: true,
      mandala: const Color(0xFFB3C7FF),
      headline: const Color(0xFFE6ECFF),
    ),
    StatusTemplate.tulasi => _Plain(
      content,
      background: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F3D1A), Color(0xFF1B5E20), Color(0xFF33691E)],
        ),
      ),
      mandala: const Color(0xFFDCEDC8),
      headline: const Color(0xFFFFF59D),
    ),
    StatusTemplate.minimal => _Plain(
      content,
      background: const BoxDecoration(color: Color(0xFF0E0B09)),
      mandala: null,
      frame: Palette.gold,
    ),
  };
}

// --- type ---------------------------------------------------------------------------------------------------------

TextStyle _headlineStyle(String lang, double size, Color color) => TextStyle(
  fontFamily: lang == 'te' ? 'Ramabhadra' : 'Mukta',
  fontFamilyFallback: uiFontFallback,
  fontWeight: lang == 'te' ? FontWeight.w400 : FontWeight.w700,
  fontSize: size,
  height: 1.2,
  color: color,
  shadows: const [Shadow(blurRadius: 10, color: Color(0x99000000))],
);

TextStyle _verseStyle(String lang, double size, Color color) => TextStyle(
  fontFamily: lang == 'te' ? 'Suranna' : scriptureFont,
  fontFamilyFallback: scriptureFontFallback,
  fontSize: lang == 'te' ? size * 1.08 : size,
  height: lang == 'te' ? 1.5 : 1.45,
  color: color,
);

TextStyle _smallStyle(double size, Color color, {FontWeight weight = FontWeight.w400}) => TextStyle(
  fontFamily: 'Mukta',
  fontFamilyFallback: uiFontFallback,
  fontSize: size,
  height: 1.35,
  color: color,
  fontWeight: weight,
);

/// Gold foil text: a vertical gold gradient through the glyphs.
class _Gold extends StatelessWidget {
  const _Gold(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (r) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFF3C4), Color(0xFFFFCA28), Color(0xFFE6A100), Color(0xFFFFE082)],
      stops: [0, 0.45, 0.7, 1],
    ).createShader(r),
    child: child,
  );
}

/// Headline, verse, meaning, chant, Panchang and signature, stacked; the middle shrinks to fit.
class _Body extends StatelessWidget {
  const _Body(
    this.c, {
    required this.ink,
    required this.headline,
    this.gold = false,
    this.padding = const EdgeInsets.fromLTRB(30, 40, 30, 30),
    this.showMeaning = true,
  });
  final StatusContent c;
  final Color ink, headline;
  final bool gold;
  final EdgeInsets padding;
  final bool showMeaning;

  @override
  Widget build(BuildContext context) {
    final lang = c.lang;
    Widget head = Text(c.headline, textAlign: TextAlign.center, style: _headlineStyle(lang, 38, headline));
    if (gold) head = _Gold(head);
    return Padding(
      padding: padding,
      child: Column(
        children: [
          head,
          const SizedBox(height: 10),
          _Divider(color: gold ? Palette.gold : headline.withValues(alpha: 0.8)),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.verse.text(lang), textAlign: TextAlign.center, style: _verseStyle(lang, 19, ink)),
                      if (showMeaning) ...[
                        const SizedBox(height: 14),
                        Text(
                          c.meaning,
                          textAlign: TextAlign.center,
                          style: _smallStyle(13.5, ink.withValues(alpha: 0.86)),
                        ),
                      ],
                      if (c.personal != null) ...[const SizedBox(height: 12), _Personal(c.personal!, color: headline)],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          gold
              ? _Gold(Text(c.chant, textAlign: TextAlign.center, style: _headlineStyle(lang, 20, headline)))
              : Text(c.chant, textAlign: TextAlign.center, style: _headlineStyle(lang, 20, headline)),
          if (c.panchang != null) ...[
            const SizedBox(height: 6),
            Text(c.panchang!, textAlign: TextAlign.center, style: _smallStyle(12.5, ink.withValues(alpha: 0.8))),
          ],
          if (c.signature != null) ...[
            const SizedBox(height: 8),
            Text(
              c.signature!,
              textAlign: TextAlign.center,
              style: _smallStyle(
                17,
                headline,
                weight: FontWeight.w700,
              ).copyWith(fontFamily: lang == 'te' ? 'Ramabhadra' : 'Mukta'),
            ),
          ],
          const SizedBox(height: 8),
          Text('Devalay', style: _smallStyle(10, ink.withValues(alpha: 0.5), weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(width: 46, height: 1.2, color: color),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 7, height: 7, color: color),
        ),
      ),
      Container(width: 46, height: 1.2, color: color),
    ],
  );
}

/// The Premium personal line, in a soft pill.
class _Personal extends StatelessWidget {
  const _Personal(this.text, {required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: _smallStyle(12.5, color, weight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

// --- free designs -----------------------------------------------------------------------------------------------

/// Neon: dark glass with a glowing saffron-to-violet outline and luminous type.
class _Neon extends StatelessWidget {
  const _Neon(this.c);
  final StatusContent c;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0620), Color(0xFF1A0B33), Color(0xFF07030F)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(top: 60, left: -60, child: _blob(const Color(0xFFFF6D00), 220)),
          Positioned(bottom: 60, right: -70, child: _blob(const Color(0xFF7C4DFF), 240)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFAB40), width: 1.6),
                boxShadow: const [
                  BoxShadow(color: Color(0x99FF6D00), blurRadius: 18),
                  BoxShadow(color: Color(0x667C4DFF), blurRadius: 30, spreadRadius: 2),
                ],
              ),
            ),
          ),
          _Body(
            c,
            ink: const Color(0xFFF3E5F5),
            headline: const Color(0xFFFFD180),
            padding: const EdgeInsets.fromLTRB(34, 46, 34, 34),
          ),
        ],
      ),
    );
  }
}

Widget _blob(Color color, double size) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)]),
  ),
);

/// Aurora: soft colour clouds (saffron, pink, violet, teal) behind clean white type.
class _Aurora extends StatelessWidget {
  const _Aurora(this.c);
  final StatusContent c;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF120A2A)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(top: -80, left: -40, child: _blob(const Color(0xFFFF8A65), 360)),
          Positioned(top: 160, right: -120, child: _blob(const Color(0xFFEC407A), 360)),
          Positioned(bottom: 40, left: -120, child: _blob(const Color(0xFF26C6DA), 380)),
          Positioned(bottom: -100, right: -60, child: _blob(const Color(0xFF7C4DFF), 340)),
          _Body(c, ink: Colors.white, headline: Colors.white),
        ],
      ),
    );
  }
}

/// Glass: the deity's photograph, blurred, under a frosted card.
class _Glass extends StatelessWidget {
  const _Glass(this.c, this.artUrl);
  final StatusContent c;
  final String? artUrl;
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (artUrl != null) NetImage(artUrl!) else const ColoredBox(color: Palette.maroon),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: const ColoredBox(color: Color(0x33000000)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 120, 18, 60),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: _Body(
                  c,
                  ink: Colors.white,
                  headline: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Plain extends StatelessWidget {
  const _Plain(
    this.c, {
    required this.background,
    required this.mandala,
    this.ink = Colors.white,
    this.headline = Palette.gold,
    this.frame,
    this.bottom,
    this.stars = false,
  });
  final StatusContent c;
  final BoxDecoration background;
  final Color? mandala, frame;
  final Color ink, headline;
  final Widget? bottom;
  final bool stars;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (stars) const CustomPaint(painter: _StarsPainter()),
          if (mandala != null)
            Positioned(
              top: -90,
              left: 0,
              right: 0,
              child: Center(child: Mandala(size: 300, color: mandala!, opacity: 0.16, spin: false)),
            ),
          if (frame != null)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: frame!.withValues(alpha: 0.7), width: 1)),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: frame!.withValues(alpha: 0.45), width: 0.6)),
                    ),
                  ),
                ),
              ),
            ),
          if (bottom != null) Positioned(left: 0, right: 0, bottom: 0, child: bottom!),
          _Body(c, ink: ink, headline: headline, gold: headline == Palette.gold),
        ],
      ),
    );
  }
}

class _ArtFull extends StatelessWidget {
  const _ArtFull(this.c, this.artUrl);
  final StatusContent c;
  final String? artUrl;
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (artUrl != null) NetImage(artUrl!) else const ColoredBox(color: Palette.maroon),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Color(0x11000000), Color(0x22000000), Color(0xE6000000)],
              stops: [0, 0.3, 0.5, 0.85],
            ),
          ),
        ),
        _Body(c, ink: Colors.white, headline: Palette.gold, gold: true, showMeaning: false),
      ],
    );
  }
}

// --- Premium designs ----------------------------------------------------------------------------------------------

/// Gold foil frame with corner ornaments over deep maroon silk.
class _Swarna extends StatelessWidget {
  const _Swarna(this.c);
  final StatusContent c;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.15,
          colors: [Color(0xFF6B0F1A), Color(0xFF3B0610), Color(0xFF1A0207)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(child: Mandala(size: 330, color: Palette.gold, opacity: 0.12, spin: false)),
          ),
          const CustomPaint(painter: _GoldFramePainter()),
          _Body(
            c,
            ink: const Color(0xFFFFF3E0),
            headline: Palette.gold,
            gold: true,
            padding: const EdgeInsets.fromLTRB(40, 52, 40, 40),
          ),
        ],
      ),
    );
  }
}

/// The deity's art in a temple-arch window with a gold rim, text on maroon below.
class _Gopuram extends StatelessWidget {
  const _Gopuram(this.c, this.artUrl);
  final StatusContent c;
  final String? artUrl;
  @override
  Widget build(BuildContext context) {
    final lang = c.lang;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A0E0E), Color(0xFF2B0606)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 26),
          _Gold(Text(c.headline, textAlign: TextAlign.center, style: _headlineStyle(lang, 30, Palette.gold))),
          const SizedBox(height: 12),
          SizedBox(
            width: 250,
            height: 300,
            child: CustomPaint(
              foregroundPainter: const _ArchRimPainter(),
              child: ClipPath(
                clipper: _ArchClipper(),
                child: artUrl != null
                    ? NetImage(artUrl!, alignment: const Alignment(0, -0.2))
                    : const ColoredBox(color: Palette.maroon),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 14, 26, 0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 308,
                  child: Text(
                    c.verse.text(lang),
                    textAlign: TextAlign.center,
                    style: _verseStyle(lang, 18, const Color(0xFFFFF3E0)),
                  ),
                ),
              ),
            ),
          ),
          _Gold(Text(c.chant, style: _headlineStyle(lang, 18, Palette.gold))),
          if (c.panchang != null) Text(c.panchang!, style: _smallStyle(12, const Color(0xCCFFF3E0))),
          if (c.personal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: _Personal(c.personal!, color: Palette.gold),
            ),
          if (c.signature != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                c.signature!,
                style: _smallStyle(
                  16,
                  Palette.gold,
                  weight: FontWeight.w700,
                ).copyWith(fontFamily: lang == 'te' ? 'Ramabhadra' : 'Mukta'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Text('Devalay', style: _smallStyle(10, const Color(0x80FFFFFF), weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Maroon silk with gold zari borders at the top and bottom, as on a pattu saree.
class _Pattu extends StatelessWidget {
  const _Pattu(this.c);
  final StatusContent c;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B0A3A), Color(0xFF5E0626), Color(0xFF7A0A33)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _SilkSheenPainter()),
          const Positioned(top: 0, left: 0, right: 0, height: 64, child: CustomPaint(painter: _ZariPainter())),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 64,
            child: RotatedBox(quarterTurns: 2, child: CustomPaint(painter: _ZariPainter())),
          ),
          _Body(
            c,
            ink: const Color(0xFFFFF0F3),
            headline: Palette.gold,
            gold: true,
            padding: const EdgeInsets.fromLTRB(30, 84, 30, 80),
          ),
        ],
      ),
    );
  }
}

/// Soft dawn colours with a painted lotus rising from the bottom.
class _Padma extends StatelessWidget {
  const _Padma(this.c);
  final StatusContent c;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6EC), Color(0xFFFFE3E0), Color(0xFFF8BBD0)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(left: 0, right: 0, bottom: -20, height: 230, child: CustomPaint(painter: _LotusPainter())),
          _Body(
            c,
            ink: const Color(0xFF4A1430),
            headline: const Color(0xFFAD1457),
            padding: const EdgeInsets.fromLTRB(30, 44, 30, 150),
          ),
        ],
      ),
    );
  }
}

/// The deity's art edge to edge inside an ornate gold frame, with a glass name plate.
class _Rajasa extends StatelessWidget {
  const _Rajasa(this.c, this.artUrl);
  final StatusContent c;
  final String? artUrl;
  @override
  Widget build(BuildContext context) {
    final lang = c.lang;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (artUrl != null) NetImage(artUrl!) else const ColoredBox(color: Palette.maroon),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB3000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
              stops: [0, 0.25, 0.55, 1],
            ),
          ),
        ),
        const CustomPaint(painter: _GoldFramePainter(inset: 10)),
        Positioned(
          top: 38,
          left: 24,
          right: 24,
          child: _Gold(Text(c.headline, textAlign: TextAlign.center, style: _headlineStyle(lang, 34, Palette.gold))),
        ),
        Positioned(
          left: 26,
          right: 26,
          bottom: 30,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0x99140804),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xAAFFC857), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 280,
                    child: Text(
                      c.verse.text(lang),
                      textAlign: TextAlign.center,
                      style: _verseStyle(lang, 16, Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Gold(Text(c.chant, style: _headlineStyle(lang, 17, Palette.gold))),
                if (c.panchang != null) Text(c.panchang!, style: _smallStyle(11.5, const Color(0xCCFFFFFF))),
                if (c.personal != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _Personal(c.personal!, color: Palette.gold),
                  ),
                if (c.signature != null)
                  Text(
                    c.signature!,
                    style: _smallStyle(
                      15,
                      Palette.gold,
                      weight: FontWeight.w700,
                    ).copyWith(fontFamily: lang == 'te' ? 'Ramabhadra' : 'Mukta'),
                  ),
                Text('Devalay', style: _smallStyle(9, const Color(0x80FFFFFF), weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- painters -----------------------------------------------------------------------------------------------------

const _goldShader = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFF1B8), Color(0xFFE0A526), Color(0xFFFFE082), Color(0xFFB8860B), Color(0xFFFFE9A6)],
);

class _GoldFramePainter extends CustomPainter {
  const _GoldFramePainter({this.inset = 14});
  final double inset;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = _goldShader.createShader(rect)
      ..style = PaintingStyle.stroke;
    final outer = rect.deflate(inset);
    canvas.drawRect(outer, paint..strokeWidth = 3);
    canvas.drawRect(outer.deflate(6), paint..strokeWidth = 1);
    // Corner ornaments: a quarter lotus of three arcs and a dot.
    final fill = Paint()..shader = _goldShader.createShader(rect);
    for (final (cx, cy, sx, sy) in [
      (outer.left, outer.top, 1.0, 1.0),
      (outer.right, outer.top, -1.0, 1.0),
      (outer.left, outer.bottom, 1.0, -1.0),
      (outer.right, outer.bottom, -1.0, -1.0),
    ]) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(sx, sy);
      for (final r in [22.0, 30.0, 38.0]) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          0,
          math.pi / 2,
          false,
          paint..strokeWidth = 1.2,
        );
      }
      canvas.drawCircle(const Offset(12, 12), 3.2, fill);
      final petal = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(26, 6, 44, 0)
        ..quadraticBezierTo(26, -2, 0, 0);
      canvas.drawPath(petal, fill);
      canvas.rotate(math.pi / 2);
      canvas.drawPath(petal, fill);
      canvas.restore();
    }
    // Small diamonds at the middle of each side.
    for (final p in [
      Offset(size.width / 2, outer.top),
      Offset(size.width / 2, outer.bottom),
      Offset(outer.left, size.height / 2),
      Offset(outer.right, size.height / 2),
    ]) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(math.pi / 4);
      canvas.drawRect(const Rect.fromLTWH(-5, -5, 10, 10), fill);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GoldFramePainter old) => old.inset != inset;
}

class _ArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => _archPath(s);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Path _archPath(Size s) {
  final w = s.width, h = s.height;
  return Path()
    ..moveTo(0, h)
    ..lineTo(0, w * 0.55)
    ..cubicTo(0, w * 0.2, w * 0.3, w * 0.08, w * 0.5, 0)
    ..cubicTo(w * 0.7, w * 0.08, w, w * 0.2, w, w * 0.55)
    ..lineTo(w, h)
    ..close();
}

class _ArchRimPainter extends CustomPainter {
  const _ArchRimPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = _goldShader.createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawPath(_archPath(size), paint);
    canvas.drawCircle(Offset(size.width / 2, -6), 5, Paint()..shader = _goldShader.createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A zari band: gold stripes and a row of temple-tooth (kottadi) triangles.
class _ZariPainter extends CustomPainter {
  const _ZariPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gold = Paint()..shader = _goldShader.createShader(rect);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.34), gold);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.40, size.width, 2), gold);
    // Temple teeth hanging from the band.
    const tooth = 18.0;
    final teeth = Path();
    for (var x = 0.0; x < size.width; x += tooth) {
      teeth
        ..moveTo(x, size.height * 0.46)
        ..lineTo(x + tooth / 2, size.height * 0.92)
        ..lineTo(x + tooth, size.height * 0.46)
        ..close();
    }
    canvas.drawPath(teeth, gold);
    // Woven dots in the solid band.
    final dot = Paint()..color = const Color(0xFF7A0A33);
    for (var x = 9.0; x < size.width; x += 18) {
      canvas.drawCircle(Offset(x, size.height * 0.17), 2.6, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SilkSheenPainter extends CustomPainter {
  const _SilkSheenPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.035);
    for (var y = -size.width; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width * 0.6), paint..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LotusPainter extends CustomPainter {
  const _LotusPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.92);
    // Leaves.
    final leaf = Paint()..color = const Color(0xFF7CB342).withValues(alpha: 0.55);
    canvas.drawOval(Rect.fromCenter(center: base.translate(-110, 6), width: 170, height: 40), leaf);
    canvas.drawOval(Rect.fromCenter(center: base.translate(110, 10), width: 170, height: 40), leaf);
    // Petals, back row first.
    void petal(double angle, double length, double width, Color a, Color b) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(width, -length * 0.35, width * 0.6, -length * 0.85, 0, -length)
        ..cubicTo(-width * 0.6, -length * 0.85, -width, -length * 0.35, 0, 0);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [a, b],
          ).createShader(Rect.fromLTWH(-width, -length, width * 2, length)),
      );
      canvas.restore();
    }

    for (final a in [-1.15, -0.75, 0.75, 1.15]) {
      petal(a, 120, 34, const Color(0xFFF48FB1), const Color(0xFFFCE4EC));
    }
    for (final a in [-0.4, 0.4]) {
      petal(a, 150, 40, const Color(0xFFEC407A), const Color(0xFFF8BBD0));
    }
    petal(0, 170, 44, const Color(0xFFD81B60), const Color(0xFFF8BBD0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 90; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.75);
      canvas.drawCircle(
        p,
        rnd.nextDouble() * 1.3 + 0.2,
        paint..color = Colors.white.withValues(alpha: rnd.nextDouble() * 0.7 + 0.2),
      );
    }
    // A crescent moon.
    final moon = Offset(size.width * 0.8, size.height * 0.1);
    canvas.drawCircle(moon, 16, Paint()..color = const Color(0xFFFFF8E1));
    canvas.drawCircle(moon.translate(7, -4), 14, Paint()..color = const Color(0xFF0A1030));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotBand extends StatelessWidget {
  const _DotBand({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(height: 26, child: CustomPaint(painter: _DotBandPainter(color)));
}

class _DotBandPainter extends CustomPainter {
  _DotBandPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withValues(alpha: 0.6);
    for (var x = 8.0; x < size.width; x += 16) {
      canvas.drawCircle(Offset(x, size.height / 2), 3, p);
      canvas.drawCircle(Offset(x + 8, size.height / 2 - 7), 1.6, p);
      canvas.drawCircle(Offset(x + 8, size.height / 2 + 7), 1.6, p);
    }
  }

  @override
  bool shouldRepaint(covariant _DotBandPainter old) => old.color != color;
}

/// A status design as a section item, so locked designs share the Premium lock flow and usage log
/// ('status_template:swarna').
class StatusTemplateItem extends SectionItem {
  StatusTemplateItem(StatusTemplate this.template)
    : super({
        'id': template.name,
        'deity': 'general',
        'title': {'en': template.en, 'te': template.te, 'hi': template.hi},
        'premium': template.premiumRank,
      });
  final StatusTemplate? template;

  /// The Premium personal-blessing line (Tarabalam from the sender's birth star).
  StatusTemplateItem.personal()
    : template = null,
      super({
        'id': 'personal',
        'deity': 'general',
        'title': {'en': 'Personal blessing', 'te': 'వ్యక్తిగత ఆశీర్వాదం', 'hi': 'व्यक्तिगत आशीर्वाद'},
        'premium': 1,
      });

  @override
  String get section => 'status_template';
}
