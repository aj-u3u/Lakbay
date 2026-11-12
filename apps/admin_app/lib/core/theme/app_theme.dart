import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Canonical Lakbay brand swatches shared with the traveler application.
  static const Color primaryColor = Color(0xFF20878E);
  static const Color secondaryColor = Color(0xFFD66F29);
  static const Color accentColor = Color(0xFF178A90);

  // Semantic variants keep normal-size text readable on filled actions.
  static const Color actionPrimary = Color(0xFF19767D);
  static const Color actionSecondary = Color(0xFFA94F18);
  static const Color darkAccent = Color(0xFF83DADF);
  static const Color mutedOnBackground = Color(0xFF5A7474);

  static const Color darkBg = Color(0xFF0D1F1F);
  static const Color darkCardBg = Color(0xFF163030);
  static const Color darkSurface = Color(0xFF112525);
  static const Color darkBorder = Color(0xFF345252);
  static const Color darkTextPrimary = Color(0xFFF0F7F7);
  static const Color darkTextSecondary = Color(0xFF8AADAD);

  static const Color lightBg = Color(0xFFF5F9F9);
  static const Color lightCardBg = Colors.white;
  static const Color lightSurface = Color(0xFFEEF5F5);
  static const Color lightBorder = Color(0xFFCFDFDF);
  static const Color lightTextPrimary = Color(0xFF1A2E2E);
  static const Color lightTextSecondary = Color(0xFF5C7878);

  static const Color success = Color(0xFF16734C);
  static const Color warning = Color(0xFF94600D);
  static const Color error = Color(0xFFB83F3F);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final text = isDark ? darkTextPrimary : lightTextPrimary;
    final muted = isDark ? darkTextSecondary : mutedOnBackground;
    final surface = isDark ? darkCardBg : lightCardBg;
    final border = isDark ? darkBorder : lightBorder;
    final interactiveText = isDark ? darkAccent : actionPrimary;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: brightness,
        ).copyWith(
          primary: interactiveText,
          onPrimary: isDark ? darkBg : Colors.white,
          secondary: isDark ? const Color(0xFFF0AA79) : actionSecondary,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: muted,
          outline: isDark ? const Color(0xFF799A9A) : const Color(0xFF789292),
          outlineVariant: border,
          error: isDark ? const Color(0xFFFFB0AC) : error,
        );

    final textTheme = GoogleFonts.outfitTextTheme(
      TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: text,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: text,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: text,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: text,
          height: 1.45,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: text,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
          height: 1.4,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: text, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: text, height: 1.55),
        bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.5),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkBg : lightBg,
      cardColor: surface,
      dividerColor: border,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: actionPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: interactiveText,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          side: BorderSide(color: scheme.outline),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: interactiveText,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: muted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurface : const Color(0xFFF0F6F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: interactiveText, width: 2),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowHeight: 48,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 88,
        headingRowColor: WidgetStatePropertyAll(
          isDark ? darkSurface : lightSurface,
        ),
        headingTextStyle: textTheme.titleSmall,
        dataTextStyle: textTheme.bodyMedium,
        dividerThickness: 1,
        horizontalMargin: 20,
        columnSpacing: 28,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? darkTextPrimary : lightTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? darkBg : Colors.white,
        ),
      ),
    );
  }
}
