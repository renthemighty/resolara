import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Resolara brand palette
  static const Color primary = Color(0xFF0E3A29);        // Deep Emerald
  static const Color background = Color(0xFF0A1F1C);     // Deep Forest Teal
  static const Color secondary = Color(0xFF73978C);      // Muted Sage
  static const Color textPrimary = Color(0xFFD4D1C7);    // Warm Stone
  static const Color accent = Color(0xFFB7A46B);         // Antique Gold

  // Derived / utility
  static const Color surface = Color(0xFF122B21);        // slightly lighter than background
  static const Color error = Color(0xFFCF6679);          // warm error, fits dark palette
  static const Color textSecondary = Color(0xFF73978C);  // Muted Sage

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: primary,
          secondary: accent,
          surface: surface,
          error: error,
          onPrimary: textPrimary,
          onSecondary: background,
          onSurface: textPrimary,
          onError: textPrimary,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: background,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: secondary),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: secondary),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: secondary, width: 0.5),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textPrimary),
          bodySmall: TextStyle(color: textSecondary),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        ),
      );
}
