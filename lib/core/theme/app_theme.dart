import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  // Backgrounds
  static const background = Color(0xFF07080F);
  static const surface = Color(0xFF0F1020);
  static const surfaceVariant = Color(0xFF161829);
  static const surfaceGlass = Color(0x1AFFFFFF);

  // Brand gradient
  static const gradientStart = Color(0xFF7B5EA7);
  static const gradientMid = Color(0xFF6C4FD9);
  static const gradientEnd = Color(0xFF4B3BC4);

  // Accents
  static const accent = Color(0xFF00D4FF);
  static const accentGreen = Color(0xFF00E5A0);
  static const accentPink = Color(0xFFFF6B9D);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8B8FAD);
  static const textMuted = Color(0xFF454761);

  // Borders
  static const border = Color(0xFF1E2038);
  static const borderGlass = Color(0x26FFFFFF);
  static const borderFocus = Color(0xFF7B5EA7);

  // States
  static const error = Color(0xFFFF5B79);
  static const success = Color(0xFF00E5A0);
  static const warning = Color(0xFFFFB347);
}

abstract final class AppGradients {
  static const brand = LinearGradient(
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const brandVertical = LinearGradient(
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const card = LinearGradient(
    colors: [Color(0xFF2A1F5E), Color(0xFF1A1340)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.gradientMid,
          onPrimary: AppColors.textPrimary,
          primaryContainer: Color(0xFF2D2060),
          onPrimaryContainer: AppColors.textPrimary,
          secondary: AppColors.accent,
          onSecondary: AppColors.background,
          secondaryContainer: Color(0xFF00374A),
          onSecondaryContainer: AppColors.textPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.error,
          onError: AppColors.textPrimary,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          prefixIconColor: AppColors.textMuted,
          suffixIconColor: AppColors.textMuted,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 1.1,
          ),
          displayMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
          bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceVariant,
          contentTextStyle: const TextStyle(color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          behavior: SnackBarBehavior.floating,
        ),
      );

  static ThemeData get light => dark;
}
