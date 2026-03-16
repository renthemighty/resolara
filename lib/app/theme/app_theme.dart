import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Resolara brand palette — fixed colours
  static const Color emerald = Color(0xFF0E3A29);    // Deep Emerald
  static const Color forestTeal = Color(0xFF0A1F1C); // Deep Forest Teal
  static const Color sage = Color(0xFF73978C);       // Muted Sage
  static const Color warmStone = Color(0xFFD4D1C7);  // Warm Stone
  static const Color gold = Color(0xFFB7A46B);       // Antique Gold

  static const String fontFamily = 'Satoshi';

  // Semantic aliases for use in const widget contexts
  static const Color primary = emerald;
  static const Color accent = gold;
  static const Color background = forestTeal;
  static const Color textPrimary = warmStone;
  static const Color textSecondary = sage;
  static const Color surface = Color(0xFF122B21);   // dark surface
  static const Color error = Color(0xFFCF6679);      // dark error

  // ── LIGHT MODE ──────────────────────────────────────────────────────────────
  // Background: Warm Stone (tan). Text: dark on light.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: fontFamily,
        colorScheme: const ColorScheme.light(
          primary: emerald,
          secondary: gold,
          surface: Color(0xFFE8E5DC),
          error: Color(0xFFB00020),
          onPrimary: warmStone,
          onSecondary: forestTeal,
          onSurface: forestTeal,
          onError: warmStone,
        ),
        scaffoldBackgroundColor: warmStone,
        appBarTheme: const AppBarTheme(
          backgroundColor: emerald,
          foregroundColor: warmStone,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: emerald,
            foregroundColor: warmStone,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFE8E5DC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: sage),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: sage),
          ),
          labelStyle: const TextStyle(color: sage),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFE8E5DC),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: sage, width: 0.5),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: forestTeal),
          bodyMedium: TextStyle(color: forestTeal),
          bodySmall: TextStyle(color: sage),
          titleLarge: TextStyle(color: forestTeal, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: forestTeal, fontWeight: FontWeight.w500),
        ),
      );

  // ── DARK MODE ───────────────────────────────────────────────────────────────
  // Background: Deep Forest Teal. Text: light on dark.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: fontFamily,
        colorScheme: const ColorScheme.dark(
          primary: emerald,
          secondary: gold,
          surface: Color(0xFF122B21),
          error: Color(0xFFCF6679),
          onPrimary: warmStone,
          onSecondary: forestTeal,
          onSurface: warmStone,
          onError: warmStone,
        ),
        scaffoldBackgroundColor: forestTeal,
        appBarTheme: const AppBarTheme(
          backgroundColor: emerald,
          foregroundColor: warmStone,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: forestTeal,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF122B21),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: sage),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: sage),
          ),
          labelStyle: const TextStyle(color: sage),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF122B21),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: sage, width: 0.5),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: warmStone),
          bodyMedium: TextStyle(color: warmStone),
          bodySmall: TextStyle(color: sage),
          titleLarge: TextStyle(color: warmStone, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: warmStone, fontWeight: FontWeight.w500),
        ),
      );
}
