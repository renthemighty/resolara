import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Resolara brand palette — fixed colours
  static const Color emerald = Color(0xFF0E3A29);        // Deep Emerald
  static const Color forestTeal = Color(0xFF0A1F1C);     // Deep Forest Teal
  static const Color sage = Color(0xFF73978C);           // Muted Sage
  static const Color warmStone = Color(0xFFD4D1C7);      // Warm Stone (dark-mode text / accents)
  static const Color lightBackground = Color(0xFFEAE7DF);// Light mode scaffold — lifted tan
  static const Color lightSurface = Color(0xFFF0EDE6);  // Light mode cards / inputs
  static const Color gold = Color(0xFFB7A46B);           // Antique Gold

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
  // Background: lifted warm tan. Text: deep forest on light.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: fontFamily,
        colorScheme: const ColorScheme.light(
          primary: emerald,
          secondary: gold,
          surface: lightSurface,
          error: Color(0xFFB00020),
          onPrimary: warmStone,
          onSecondary: forestTeal,
          onSurface: forestTeal,
          onError: warmStone,
        ),
        scaffoldBackgroundColor: lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: emerald,
          foregroundColor: warmStone,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: warmStone,
            letterSpacing: 0.2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: emerald,
            foregroundColor: warmStone,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: emerald,
            side: const BorderSide(color: emerald, width: 1.5),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: emerald,
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: sage),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: sage),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: emerald, width: 1.5),
          ),
          labelStyle: const TextStyle(color: sage),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        cardTheme: CardThemeData(
          color: lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: sage, width: 0.5),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? gold : warmStone,
              size: 24,
            );
          }),
        ),
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(color: forestTeal, fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(color: forestTeal, fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall:  TextStyle(color: sage,       fontSize: 12, fontWeight: FontWeight.w400),
          titleLarge: TextStyle(color: forestTeal, fontSize: 20, fontWeight: FontWeight.w700),
          titleMedium:TextStyle(color: forestTeal, fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: forestTeal, fontSize: 14, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(color: forestTeal, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );

  // ── DARK MODE ───────────────────────────────────────────────────────────────
  // Background: Deep Forest Teal. Text: warm stone on dark.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: fontFamily,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: emerald,
          surface: Color(0xFF122B21),
          error: error,
          onPrimary: forestTeal,
          onSecondary: warmStone,
          onSurface: warmStone,
          onError: warmStone,
        ),
        scaffoldBackgroundColor: forestTeal,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D2820),
          foregroundColor: warmStone,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: warmStone,
            letterSpacing: 0.2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: forestTeal,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: gold,
            side: const BorderSide(color: gold, width: 1.5),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: gold,
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: gold, width: 1.5),
          ),
          labelStyle: const TextStyle(color: sage),
          hintStyle: const TextStyle(color: sage),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF122B21),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E4535), width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? gold : warmStone,
              size: 24,
            );
          }),
        ),
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(color: warmStone,    fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(color: warmStone,    fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall:  TextStyle(color: sage,         fontSize: 12, fontWeight: FontWeight.w400),
          titleLarge: TextStyle(color: warmStone,    fontSize: 20, fontWeight: FontWeight.w700),
          titleMedium:TextStyle(color: warmStone,    fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: warmStone,    fontSize: 14, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(color: warmStone,    fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
}
