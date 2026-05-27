import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Lakbay Brand Palette ──────────────────────────────────────────────────
  static const Color primaryBlue    = Color(0xFF20878E); // Dark Cyan (primary)
  static const Color secondaryGreen = Color(0xFFD66F29); // Cocoa Brown (secondary)
  static const Color accentTeal     = Color(0xFF178A90); // Slightly deeper cyan accent
  static const Color backgroundLight = Color(0xFFF5F9F9); // Warm off-white
  static const Color cardColorLight  = Colors.white;
  static const Color textPrimaryLight   = Color(0xFF1A2E2E); // Deep teal-tinted dark
  static const Color textSecondaryLight = Color(0xFF5C7878); // Muted teal-gray

  static const Color backgroundDark  = Color(0xFF0D1F1F); // Very deep teal-black
  static const Color cardColorDark   = Color(0xFF163030); // Dark teal card
  static const Color textPrimaryDark    = Color(0xFFF0F7F7);
  static const Color textSecondaryDark  = Color(0xFF8AADAD);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: secondaryGreen,
        tertiary: accentTeal,
        background: backgroundLight,
        surface: cardColorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: textPrimaryLight,
        onSurface: textPrimaryLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardTheme: CardThemeData(
        color: cardColorLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryLight),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimaryLight),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimaryLight),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryLight),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryLight),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimaryLight),
          bodyMedium: TextStyle(fontSize: 14, color: textSecondaryLight),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryLight),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryBlue),
        titleTextStyle: TextStyle(
          color: primaryBlue,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColorLight,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textSecondaryLight,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: secondaryGreen,
        tertiary: accentTeal,
        background: backgroundDark,
        surface: cardColorDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: textPrimaryDark,
        onSurface: textPrimaryDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardTheme: CardThemeData(
        color: cardColorDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryDark),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimaryDark),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimaryDark),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryDark),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryDark),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimaryDark),
          bodyMedium: TextStyle(fontSize: 14, color: textSecondaryDark),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryDark),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColorDark,
        selectedItemColor: secondaryGreen,
        unselectedItemColor: textSecondaryDark,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
