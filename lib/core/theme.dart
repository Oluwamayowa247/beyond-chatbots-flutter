import 'package:flutter/material.dart';

/// Colours lifted from the FlutterBytes 2026 deck.
abstract final class Brand {
  static const navy = Color(0xFF06234A);
  static const navyCard = Color(0xFF0D3263);
  static const blue = Color(0xFF1976D2);
  static const sky = Color(0xFF2E9BF0);
  static const mist = Color(0xFFEAF3FD);
  static const muted = Color(0xFF8FA6C4);
  static const success = Color(0xFF1E9E5A);
  static const danger = Color(0xFFD64545);
}

ThemeData buildStageTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter', // bundled in assets/fonts, works offline
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Brand.blue,
      brightness: Brightness.dark,
      surface: Brand.navy,
    ),
    scaffoldBackgroundColor: Brand.navy,
  );
  return base;
}

/// Theme for the "phone" apps. Pattern 03 flips this between light and dark.
ThemeData buildPhoneTheme(Brightness brightness, {Color seed = Brand.blue}) {
  final dark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter', // bundled in assets/fonts, works offline
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: dark ? const Color(0xFF0F1724) : const Color(0xFFF4F7FB),
    ),
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0F1724)
        : const Color(0xFFF4F7FB),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1A2536) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF2A3A52) : const Color(0xFFE1E7EF),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF2A3A52) : const Color(0xFFE1E7EF),
        ),
      ),
    ),
  );
  return base;
}
