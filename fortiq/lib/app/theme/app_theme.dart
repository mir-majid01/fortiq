import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the Fortiq dark theme. Screens style themselves through the
/// [AppColors] / [AppTypography] tokens; this theme only supplies sane
/// defaults (canvas colour, control tint, no Material font leakage).
ThemeData buildFortiqTheme() {
  final scheme = ColorScheme.dark(
    primary: AppColors.gold,
    onPrimary: AppColors.onGold,
    surface: AppColors.background,
    onSurface: AppColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Manrope'),
      displayMedium: TextStyle(fontFamily: 'Manrope'),
      displaySmall: TextStyle(fontFamily: 'Manrope'),
      headlineLarge: TextStyle(fontFamily: 'Manrope'),
      headlineMedium: TextStyle(fontFamily: 'Manrope'),
      headlineSmall: TextStyle(fontFamily: 'Manrope'),
      titleLarge: TextStyle(fontFamily: 'Manrope'),
      titleMedium: TextStyle(fontFamily: 'Manrope'),
      bodyLarge: TextStyle(fontFamily: 'Inter'),
      bodyMedium: TextStyle(fontFamily: 'Inter'),
      bodySmall: TextStyle(fontFamily: 'Inter'),
      labelLarge: TextStyle(fontFamily: 'Inter'),
      labelMedium: TextStyle(fontFamily: 'Inter'),
      labelSmall: TextStyle(fontFamily: 'Inter'),
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.card,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.card,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderEmphasis),
      ),
      textStyle: AppTypography.chipSelected,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBarrierColor: AppColors.scrim,
    ),
  );
}
