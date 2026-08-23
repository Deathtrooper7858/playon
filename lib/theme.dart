import 'package:flutter/material.dart';

class PlayOnTheme {
  // Ultra-Deep Midnight & Nebula Palette
  static const Color bgDeep = Color(0xFF07070D);
  static const Color bgCard = Color(0xFF0E0B1A);
  static const Color bgSurface = Color(0xFF161228);
  static const Color bgSurfaceElevated = Color(0xFF201B38);

  // Vibrant Accents
  static const Color purplePrimary = Color(0xFF8B5CF6);
  static const Color purpleGlow = Color(0xFFA78BFA);
  static const Color purpleDim = Color(0xFF4C1D95);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color cyanAccent = Color(0xFF06B6D4);
  static const Color emeraldActive = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);

  // Text & Borders
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color divider = Color(0xFF26203D);
  static const Color glassBorder = Color(0x1AFFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [purplePrimary, pinkAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [cyanAccent, purplePrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF130F24), Color(0xFF0A0714)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Reusable Glow Shadows
  static List<BoxShadow> glowShadow({Color color = purplePrimary, double blur = 20, double spread = 0}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: purplePrimary,
          secondary: pinkAccent,
          tertiary: cyanAccent,
          surface: bgCard,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDeep,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: bgCard,
          selectedItemColor: purplePrimary,
          unselectedItemColor: textSecondary,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 15),
          bodyMedium: TextStyle(color: textSecondary, fontSize: 13.5),
          bodySmall: TextStyle(color: textTertiary, fontSize: 12),
        ),
      );
}
