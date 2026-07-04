import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme({bool largeText = false}) {
    final baseSize = largeText ? 18.0 : 16.0;
    final titleSize = largeText ? 22.0 : 20.0;
    final buttonHeight = largeText ? 56.0 : 48.0;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        error: AppColors.alert,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: GoogleFonts.notoSansGujarati().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.notoSansGujarati(
          fontSize: titleSize + 8,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.notoSansGujarati(
          fontSize: titleSize + 4,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.notoSansGujarati(
          fontSize: titleSize,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: GoogleFonts.notoSansGujarati(
          fontSize: titleSize - 2,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.notoSansGujarati(
          fontSize: baseSize + 2,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.notoSansGujarati(
          fontSize: baseSize,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.notoSansGujarati(
          fontSize: baseSize,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.notoSansGujarati(
          fontSize: baseSize - 2,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: GoogleFonts.notoSansGujarati(
          fontSize: baseSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size.fromHeight(buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}
