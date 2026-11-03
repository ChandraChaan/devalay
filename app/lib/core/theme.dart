import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Saffron, marigold and sandalwood palette with a warm night theme.
class Palette {
  static const saffron = Color(0xFFE65100);
  static const marigold = Color(0xFFFFA000);
  static const vermilion = Color(0xFFC62828);
  static const sandal = Color(0xFFFFF4E6);
  static const cream = Color(0xFFFFFAF3);
  static const maroon = Color(0xFF5D1A0B);
  static const gold = Color(0xFFFFC857);
  static const night = Color(0xFF120C09);
  static const nightCard = Color(0xFF1F1611);
  static const nightRaised = Color(0xFF2A1E17);
  static const ink = Color(0xFF2B1A12); // warm near-black for light-mode text
  static const parchment = Color(0xFFF3E9DF); // warm off-white for dark-mode text

  static const sunrise = [Color(0xFFFF8F00), Color(0xFFE65100), Color(0xFFB71C1C)];
  static const dusk = [Color(0xFF4A148C), Color(0xFF880E4F), Color(0xFFE65100)];
  static const tulsi = [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF66BB6A)];
  static const sky = [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF4FC3F7)];

  static Color hex(String value, {Color fallback = saffron}) {
    final v = value.replaceFirst('#', '');
    final parsed = int.tryParse(v.length == 6 ? 'FF$v' : v, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }
}

/// App colour themes the user can pick in Settings. Each pairs a light-mode primary with a
/// softer dark-mode primary that keeps contrast on the warm night background.
enum Accent {
  saffron('Saffron', 'केसरिया', 'కాషాయం', Color(0xFFE65100), Color(0xFFFFB74D)),
  kumkum('Kumkum', 'कुमकुम', 'కుంకుమ', Color(0xFFB3261E), Color(0xFFFF8A80)),
  tulsi('Tulsi', 'तुलसी', 'తులసి', Color(0xFF2E7D32), Color(0xFF81C784)),
  peacock('Peacock', 'मोरपंखी', 'నెమలి నీలం', Color(0xFF00658F), Color(0xFF7FD0FF)),
  lotus('Lotus', 'कमल', 'తామర', Color(0xFFAD1457), Color(0xFFFF8BC4));

  const Accent(this.en, this.hi, this.te, this.light, this.dark);
  final String en, hi, te;
  final Color light, dark;

  static Accent byName(String? name) => Accent.values.where((a) => a.name == name).firstOrNull ?? Accent.saffron;
}

const _ui = 'Mukta';
const scriptureFont = 'TiroDevanagari';
// Mukta and Tiro Devanagari have no Telugu letters; these bundled fonts fill in.
const uiFontFallback = ['NotoSansTelugu'];
const scriptureFontFallback = ['TiroTelugu', 'NotoSansTelugu'];

ThemeData buildTheme(Brightness brightness, [Accent accent = Accent.saffron]) {
  final dark = brightness == Brightness.dark;
  final primary = dark ? accent.dark : accent.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: accent.light,
    brightness: brightness,
    primary: primary,
    secondary: dark ? Palette.gold : Palette.marigold,
    surface: dark ? Palette.night : Palette.cream,
    onSurface: dark ? Palette.parchment : Palette.ink,
    surfaceContainerLowest: dark ? Palette.night : Colors.white,
    surfaceContainerLow: dark ? Palette.nightCard : const Color(0xFFFFF6EC),
    surfaceContainer: dark ? Palette.nightCard : const Color(0xFFFCEFE2),
    surfaceContainerHigh: dark ? Palette.nightRaised : const Color(0xFFF8E8D8),
  );
  const ui = TextStyle(fontFamily: _ui, fontFamilyFallback: uiFontFallback);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _ui, brightness: brightness);
  final textTheme = base.textTheme.apply(
    fontFamily: _ui,
    fontFamilyFallback: uiFontFallback,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final cardBorder = BorderSide(color: scheme.outlineVariant.withValues(alpha: dark ? 0.35 : 0.5));
  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _ui, fontFamilyFallback: uiFontFallback),
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: ui.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? Palette.nightCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: cardBorder),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(iconColor: scheme.primary, titleTextStyle: textTheme.titleMedium),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.4), space: 1),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: ui.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
      secondaryLabelStyle: ui.copyWith(fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
      selectedColor: scheme.primaryContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: dark ? Palette.nightCard : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(
        ui.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? Palette.nightCard : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      selectedLabelTextStyle: ui.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary),
      unselectedLabelTextStyle: ui.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: ui.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(selectedBackgroundColor: scheme.primary.withValues(alpha: 0.18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Palette.nightCard : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: cardBorder),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

TextStyle scriptureStyle(BuildContext context, {double size = 20, FontWeight weight = FontWeight.w400}) => TextStyle(
  fontFamily: scriptureFont,
  fontFamilyFallback: scriptureFontFallback,
  fontSize: size,
  height: 1.75,
  fontWeight: weight,
  color: Theme.of(context).colorScheme.onSurface,
);

/// Width breakpoints shared by layouts: phones get bottom navigation, wider screens a rail.
abstract final class Breakpoints {
  static const rail = 840.0;
  static const content = 960.0; // reading width for lists on tablets
}
