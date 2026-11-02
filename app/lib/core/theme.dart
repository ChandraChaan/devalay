import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Saffron, marigold and sandalwood palette with a warm night theme.
class Palette {
  static const saffron = Color(0xFFE65100);
  static const marigold = Color(0xFFFFA000);
  static const vermilion = Color(0xFFC62828);
  static const sandal = Color(0xFFFFF4E6);
  static const cream = Color(0xFFFFFBF5);
  static const maroon = Color(0xFF5D1A0B);
  static const gold = Color(0xFFFFC857);
  static const night = Color(0xFF140D0A);
  static const nightCard = Color(0xFF221712);

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

const _ui = 'Mukta';
const scriptureFont = 'TiroDevanagari';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.saffron,
    brightness: brightness,
    primary: dark ? const Color(0xFFFFB74D) : Palette.saffron,
    secondary: dark ? Palette.gold : Palette.marigold,
    surface: dark ? Palette.night : Palette.cream,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _ui, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(fontFamily: _ui, fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? Palette.nightCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(fontFamily: _ui, fontWeight: FontWeight.w600, color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(fontFamily: _ui, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
      selectedColor: scheme.primaryContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: dark ? Palette.nightCard : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: _ui, fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: _ui, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Palette.nightCard : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
  fontSize: size,
  height: 1.75,
  fontWeight: weight,
  color: Theme.of(context).colorScheme.onSurface,
);
