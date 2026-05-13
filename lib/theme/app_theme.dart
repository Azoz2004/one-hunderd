import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Palette (matching the physical sticker) ───────────────────────────
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFEDE8E2);
  static const Color cardFill = Color(0xFFF5F0EA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF9E9890);
  static const Color green = Color(0xFF4CAF50);
  static const Color greenLight = Color(0xFFE8F5E9);
  static const Color border = Color(0xFFC8C2BA);
  static const Color borderLight = Color(0xFFDDD7CF);
  static const Color decorArc = Color(0xFFDDD7CF);
  static const Color error = Color(0xFFD32F2F);
  static const Color white = Color(0xFFFFFFFF);
  static const Color googleBlue = Color(0xFF4285F4);
}

// ─── Theme ───────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.charcoal,
        secondary: AppColors.green,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.charcoal,
        onError: AppColors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.charcoal,
          fontSize: 16,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.charcoal,
          fontSize: 14,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.charcoal,
          foregroundColor: AppColors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.charcoal,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.charcoal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 32,
      ),
    );
  }
}
