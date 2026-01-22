// lib/theme/know_no_know_theme.dart
import 'package:flutter/material.dart';

class KnowNoKnowTheme {
  // ---------------------------------------------------------------------------
// Legacy / compatibility helpers (so old screens still compile)
// ---------------------------------------------------------------------------

static const Color subwayBlack = Color(0xFF0B0B0C);
static const Color subwayWhite = Color(0xFFFFFFFF);

// Many older screens used "muted" as a text color
static const Color muted = mutedInk;

// Some older screens reference "yellow" (used for accents)
static const Color yellow = Color(0xFFFFD54A);

// Used by subway_circle.dart for route badge text contrast
static Color routeTextColor(Color routeColor) {
  // Simple luminance check: dark bg => white text, light bg => black text
  final lum = routeColor.computeLuminance();
  return lum > 0.55 ? subwayBlack : subwayWhite;
}
  // ---------------------------------------------------------------------------
  // BRAND
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFFB75AFE); // #B75AFE
  static const Color ink = Color(0xFF0B0B0C); // near-black
  static const Color white = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // BACKGROUNDS
  // ---------------------------------------------------------------------------
  static const Color softWhite = Color(0xFFF6F6F7);
  static const Color bg1 = Color(0xFFF8F7FF); // lavender haze
  static const Color bg2 = Color(0xFFF1ECFF); // soft purple wash
  static const Color bg3 = Color(0xFFF7F7F8); // neutral base

  // ---------------------------------------------------------------------------
  // TEXT / ACCENTS
  // ---------------------------------------------------------------------------
  static const Color charcoal = Color(0xFF141417);

  /// Use this for secondary text. Keep it readable (not too faded).
  static const Color mutedInk = Color(0x99141417); // ~60%

  // ---------------------------------------------------------------------------
  // STROKES / BORDERS (crisper, still subtle)
  // ---------------------------------------------------------------------------
  static const Color stroke = Color(0x33141417);
  static const Color strokeStrong = Color(0x66141417);

  // ---------------------------------------------------------------------------
  // SURFACES
  // ---------------------------------------------------------------------------
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panel2 = Color(0xFFF4F4F6);

  // ---------------------------------------------------------------------------
  // STAT PILL SYSTEM (calm + premium)
  // ---------------------------------------------------------------------------
  static const Color pillFill = Color(0xFF1B1B1F); // charcoal chip
  static const Color pillFillText = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // RADIUS
  // ---------------------------------------------------------------------------
  static const double rCard = 22;
  static const double rBtn = 20;
  static const double rChip = 999;

  // ---------------------------------------------------------------------------
  // GRADIENTS
  // ---------------------------------------------------------------------------
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg1, bg2, bg3],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF6D2BFF)],
  );

  // Cards: slightly tinted but basically white (better separation)
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFBFAFF)],
  );

  // ---------------------------------------------------------------------------
  // THEME
  // ---------------------------------------------------------------------------
  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Arimo',
      splashFactory: InkSparkle.splashFactory,
    );

    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: white,
      surface: panel,
      onSurface: ink,
      background: softWhite,
      onBackground: ink,
    );

    final text = base.textTheme.copyWith(
      displaySmall: const TextStyle(
        color: ink,
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
        height: 1.0,
      ),
      headlineMedium: const TextStyle(
        color: ink,
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
        height: 1.05,
      ),
      titleLarge: const TextStyle(
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
      ),
      titleMedium: const TextStyle(
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
      bodyLarge: const TextStyle(
        color: ink,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      bodyMedium: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      bodySmall: const TextStyle(
        color: mutedInk,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      labelLarge: const TextStyle(
        color: ink,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
      ),
      labelMedium: const TextStyle(
        color: mutedInk,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
      ),
    );

    return base.copyWith(
      colorScheme: cs,
      textTheme: text,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
        iconTheme: IconThemeData(color: ink),
      ),

      dividerTheme: const DividerThemeData(
        color: stroke,
        thickness: 1,
        space: 1,
      ),

      // Default ElevatedButton = brand primary
      // (You override CTA to black inside today_screen.dart)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return stroke;
            return primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return mutedInk;
            return white;
          }),
          overlayColor: WidgetStateProperty.all(white.withOpacity(0.12)),
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rBtn)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(ink),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w900),
          ),
          overlayColor: WidgetStateProperty.all(ink.withOpacity(0.08)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rBtn)),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(ink),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: stroke, width: 1.2);
            }
            return const BorderSide(color: strokeStrong, width: 1.4);
          }),
          overlayColor: WidgetStateProperty.all(ink.withOpacity(0.06)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rBtn)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3),
          ),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: ink,
        textColor: ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel2,
        hintStyle: const TextStyle(color: mutedInk, fontWeight: FontWeight.w800),
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w900),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: stroke, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),

      // Chips (if you ever use Chip widgets) match the pill system
      chipTheme: ChipThemeData(
        backgroundColor: pillFill,
        selectedColor: pillFill,
        disabledColor: stroke,
        labelStyle: const TextStyle(
          color: pillFillText,
          fontWeight: FontWeight.w900,
        ),
        secondaryLabelStyle: const TextStyle(
          color: pillFillText,
          fontWeight: FontWeight.w900,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rChip),
          side: const BorderSide(color: stroke, width: 1.2),
        ),
      ),
    );
  }
}
