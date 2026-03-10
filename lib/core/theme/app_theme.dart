import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'app_theme_extension.dart';

/// Builds the LinkHive light theme.
ThemeData buildLinkHiveTheme() {
  return _buildTheme(
    brightness: Brightness.light,
    background: AppColors.background,
    surface: AppColors.surface,
    secondarySurface: AppColors.secondarySurface,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    shadowColor: AppColors.shadowMint,
  );
}

/// Builds the LinkHive dark theme.
ThemeData buildLinkHiveDarkTheme() {
  return _buildTheme(
    brightness: Brightness.dark,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    secondarySurface: AppColors.secondarySurfaceDark,
    border: AppColors.borderDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    shadowColor: AppColors.gray800, // Subtler shadow for dark mode
  );
}

/// Base theme builder to ensure consistency across light and dark modes.
ThemeData _buildTheme({
  required Brightness brightness,
  required Color background,
  required Color surface,
  required Color secondarySurface,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  required Color textTertiary,
  required Color shadowColor,
}) {
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,

    // ─── Color Scheme ─────────────────────────────────────────────
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.white : AppColors.black,
      onPrimary: isDark ? AppColors.black : AppColors.white,
      secondary: AppColors.black,
      onSecondary: AppColors.white,
      surface: surface,
      onSurface: textPrimary,
      error: AppColors.error,
      onError: AppColors.white,
      outline: border,
      surfaceContainerHighest: secondarySurface,
    ),

    // ─── Custom Neo-Brutalist Extension ───────────────────────────
    extensions: [AppNeoBrutalTheme(shadowColor: shadowColor, borderColor: border, borderWidth: 2.0)],

    // ─── Typography ───────────────────────────────────────────────
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: textPrimary),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: textPrimary),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: textPrimary),
      titleLarge: AppTypography.titleLarge.copyWith(color: textPrimary),
      titleMedium: AppTypography.titleMedium.copyWith(color: textPrimary),
      titleSmall: AppTypography.titleSmall.copyWith(color: textPrimary),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: textPrimary),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: textPrimary),
      bodySmall: AppTypography.bodySmall.copyWith(color: textSecondary),
      labelLarge: AppTypography.labelLarge.copyWith(color: textPrimary),
      labelSmall: AppTypography.labelSmall.copyWith(color: textPrimary),
    ),

    // ─── Components ───────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTypography.titleLarge.copyWith(color: textPrimary),
      iconTheme: IconThemeData(color: textPrimary, size: 24),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        side: BorderSide(color: border, width: 2),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        borderSide: BorderSide(color: border, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        borderSide: BorderSide(color: border, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        borderSide: BorderSide(color: border, width: 3),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(color: textTertiary),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.white : AppColors.black,
        foregroundColor: isDark ? AppColors.black : AppColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        textStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: isDark ? AppColors.white : AppColors.black,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
      labelStyle: AppTypography.labelLarge.copyWith(color: textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        side: BorderSide(color: border, width: 2),
      ),
    ),

    dividerTheme: DividerThemeData(color: secondarySurface, thickness: 2, space: 1),
  );
}
