import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1A1A1A);
  static const Color secondaryColor = Color(0xFF2A2A2A);
  static const Color accentColor = Color(0xff296e48);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A0);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: primaryColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: secondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryColor,
        hintStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  static TextStyle get titleLarge => const TextStyle(
    color: textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static TextStyle get titleMedium => const TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get bodyMedium =>
      const TextStyle(color: textSecondary, fontSize: 14);

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: secondaryColor,
    borderRadius: BorderRadius.circular(15),
    border: Border.all(color: const Color(0xFF404040)),
  );
}
