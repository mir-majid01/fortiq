import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Fortiq typography.
///
/// Manrope carries headings, branding and prominent numbers.
/// Inter carries body text, labels and supporting information.
/// Sizes, weights, letter-spacing and colours mirror the HTML reference.
abstract final class AppTypography {
  static const String display = 'Manrope';
  static const String body = 'Inter';

  // ---- Branding -----------------------------------------------------------
  /// FORTIQ wordmark. Reference sizes: 32 (Splash), 15 (Home), 14 (Onboarding).
  static TextStyle brand(double size, {double letterSpacingEm = 0.2}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: size * letterSpacingEm,
        color: AppColors.textPrimary,
      );

  static const TextStyle splashTagline = TextStyle(
    fontFamily: body,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.64, // .24em @ 11px
    color: AppColors.textSecondary,
  );

  // ---- Home ---------------------------------------------------------------
  static const TextStyle greetingLabel = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle greetingTitle = TextStyle(
    fontFamily: display,
    fontSize: 22,
    height: 1.0,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: display,
    fontSize: 17,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionAction = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
  );

  // ---- Chips & badges ------------------------------------------------------
  static const TextStyle chipSelected = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  static const TextStyle chipUnselected = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textSecondary,
  );

  static const TextStyle categoryChip = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle hallBadge = TextStyle(
    fontFamily: body,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.gold,
  );

  static const TextStyle exploreBadge = TextStyle(
    fontFamily: body,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.gold,
  );

  // ---- Cards ---------------------------------------------------------------
  static const TextStyle featuredTitle = TextStyle(
    fontFamily: display,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle featuredSubtle = TextStyle(
    fontFamily: body,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textCardSubtle,
  );

  static const TextStyle freshnessLabel = TextStyle(
    fontFamily: body,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.success,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: body,
    fontSize: 15,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: body,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle cardTime = TextStyle(
    fontFamily: body,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.success,
  );

  static const TextStyle copiesLabel = TextStyle(
    fontFamily: body,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textOnImage,
  );

  // ---- Explore -------------------------------------------------------------
  static const TextStyle screenTitle = TextStyle(
    fontFamily: display,
    fontSize: 24,
    height: 1.0,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle searchField = TextStyle(
    fontFamily: body,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle searchHint = TextStyle(
    fontFamily: body,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle resultCount = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textSecondary,
  );

  static const TextStyle resultName = TextStyle(
    fontFamily: body,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle ratingLabel = TextStyle(
    fontFamily: body,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  static const TextStyle countBadge = TextStyle(
    fontFamily: body,
    fontSize: 10,
    height: 1.0,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.gold,
  );

  // ---- Filters sheet -------------------------------------------------------
  static const TextStyle filtersTitle = TextStyle(
    fontFamily: display,
    fontSize: 20,
    height: 1.0,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle filterGroup = TextStyle(
    fontFamily: body,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2, // .1em @ 12px
    color: AppColors.textSecondary,
  );

  static const TextStyle switchLabel = TextStyle(
    fontFamily: body,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ---- Base detail ---------------------------------------------------------
  static const TextStyle detailTitle = TextStyle(
    fontFamily: display,
    fontSize: 26,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle detailChipActive = TextStyle(
    fontFamily: body,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.gold,
  );

  static const TextStyle detailChip = TextStyle(
    fontFamily: body,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textCardSubtle,
  );

  static const TextStyle creatorName = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textCardSubtle,
  );

  static const TextStyle followLabel = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
  );

  static const TextStyle statStrong = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  static const TextStyle statLabel = TextStyle(
    fontFamily: body,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textSecondary,
  );

  static const TextStyle verifiedLine = TextStyle(
    fontFamily: body,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ---- Onboarding ----------------------------------------------------------
  static const TextStyle onboardingKicker = TextStyle(
    fontFamily: body,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.44, // .12em @ 12px
    color: AppColors.gold,
  );

  static const TextStyle onboardingTitle = TextStyle(
    fontFamily: display,
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle onboardingBody = TextStyle(
    fontFamily: body,
    fontSize: 15,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ---- Bottom nav ----------------------------------------------------------
  static const TextStyle navLabel = TextStyle(
    fontFamily: body,
    fontSize: 11,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ---- Buttons -------------------------------------------------------------
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: body,
    fontSize: 16,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: AppColors.onGold,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: body,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w700,
    color: AppColors.onGold,
  );

  static const TextStyle buttonReset = TextStyle(
    fontFamily: body,
    fontSize: 15,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle skipLabel = TextStyle(
    fontFamily: body,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  // ---- Avatar --------------------------------------------------------------
  static TextStyle avatarInitial(double size) => TextStyle(
        fontFamily: display,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
}
