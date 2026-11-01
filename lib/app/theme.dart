import 'package:flutter/material.dart';

import '../core/constants.dart';

/// MXFF AI visual language: AMOLED black, neon red core, neon green energy,
/// cyan secondary glow, glassmorphism panels.
class MxffTheme {
  MxffTheme._();

  static ThemeData dark() {
    final scheme = const ColorScheme.dark(
      primary: kNeonGreen,
      onPrimary: Color(0xFF02130C),
      secondary: kCyan,
      onSecondary: Color(0xFF021318),
      tertiary: kNeonRed,
      onTertiary: Color(0xFF1A0208),
      surface: kPanel,
      onSurface: Color(0xFFF2F6F5),
      surfaceContainerHighest: kPanelStrong,
      onSurfaceVariant: Color(0xFF9FB0AC),
      error: Color(0xFFFF5A6E),
      onError: Color(0xFF1A0208),
      outline: Color(0x332EE8B0),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: kBackground,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35),
        bodySmall: TextStyle(fontSize: 12, height: 1.3),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      ),
      cardTheme: CardThemeData(
        color: kPanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x262EE8B0)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kPanelStrong,
        hintStyle: const TextStyle(color: Color(0xFF63706E)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x332EE8B0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x2B2EE8B0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: kNeonGreen, width: 1.4),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: kPanelStrong,
        contentTextStyle: TextStyle(color: Color(0xFFF2F6F5)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: kPanelStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1A2EE8B0), thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? kBackground : const Color(0xFF8AA39C)),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? kNeonGreen : const Color(0xFF22303B)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: kNeonGreen,
        thumbColor: kNeonGreen,
        inactiveTrackColor: Color(0xFF22303B),
      ),
    );
  }
}
