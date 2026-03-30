// lib/theme/know_no_know_theme.dart
import 'package:flutter/material.dart';

class KnowNoKnowTheme {
  // ---- Core colors ----
  static const Color primary = Color(0xFFB75AFE); // purple accent
  static const Color ink = Color(0xFF111111);     // near-black text
  static const Color mutedInk = Color(0xFF5B5B5B);
  static const Color white = Color(0xFFFFFFFF);

  // Surfaces / strokes
  static const Color stroke = Color(0x1A000000); // subtle border
  static const Color panel = Color(0x0FFFFFFF);  // translucent panel

  // Pills
  static const Color pillFill = Color(0x14000000);
  static const Color pillFillText = Color(0xFF111111);

  // ✅ Background gradient used by app_router + multiple screens
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0B0B0E),
      Color(0xFF121019),
      Color(0xFF1A1326),
    ],
  );

  // Card gradient used throughout
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF5F1FF),
    ],
  );

  /// App ThemeData (optional)
  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
    );

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        surface: Colors.transparent,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.92),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(
          color: mutedInk.withOpacity(0.7),
          fontWeight: FontWeight.w800,
        ),
        prefixStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w900,
        ),
        prefixIconColor: mutedInk,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: stroke.withOpacity(0.9), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: stroke.withOpacity(0.9), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
