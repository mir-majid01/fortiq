import 'package:flutter/material.dart';

/// Fortiq design-system colour tokens.
///
/// Every value is lifted directly from the approved HTML reference
/// (Splash / Onboarding / Main / Explore / Filters / Detail / BasePreview).
abstract final class AppColors {
  // Surfaces
  static const Color background = Color(0xFF0B0D10);
  static const Color surface = Color(0xFF11151A);
  static const Color card = Color(0xFF171C23);
  static const Color navBackground = Color(0xF5171C23); // rgba(23,28,35,.96)
  static const Color scrim = Color(0xFF050607); // Filters-sheet backdrop

  // Brand gold
  static const Color gold = Color(0xFFD6A84F);
  static const Color goldBright = Color(0xFFE6BF68); // emblem highlights
  static const Color onGold = Color(0xFF14100A);

  // Text
  static const Color textPrimary = Color(0xFFF2F4F7);
  static const Color textSecondary = Color(0xFF929BA8);
  static const Color textCardSubtle = Color(0xFFC9CFD8);
  static const Color textOnImage = Color(0xFFE3E7ED);

  // Semantic
  static const Color success = Color(0xFF6DAE8B);
  static const Color error = Color(0xFFE36B6B);

  // Borders — rgba(255,255,255,x)
  static const Color border = Color(0x0FFFFFFF); // .06
  static const Color borderStrong = Color(0x14FFFFFF); // .08
  static const Color borderEmphasis = Color(0x1AFFFFFF); // .10
  static const Color borderAction = Color(0x24FFFFFF); // .14
  static const Color borderNav = Color(0x12FFFFFF); // .07 (bottom nav)
  static const Color borderGoldSoft = Color(0x73D6A84F); // rgba(214,168,79,.45)

  // Gold washes — rgba(214,168,79,x)
  static const Color goldWash10 = Color(0x1AD6A84F); // .10
  static const Color goldWash12 = Color(0x1FD6A84F); // .12
  static const Color goldWash18 = Color(0x2ED6A84F); // .18

  // Controls
  static const Color segmentSelected = Color(0xFF1E2530); // Home toggle
  static const Color segmentSelectedSheet = Color(0xFF252D3A); // Filters toggle
  static const Color chipInactive = Color(0xFF2A323D); // dots / separators
  static const Color badgeBackdrop = Color(0xCC0B0D10); // rgba(11,13,16,.8)
  static const Color controlBackdrop = Color(0xBF0B0D10); // rgba(11,13,16,.75)

  // Scrim gradients over base previews (rgba(11,13,16,x))
  static const Color previewScrim40 = Color(0x660B0D10); // .40
  static const Color previewScrim50 = Color(0x800B0D10); // .50
  static const Color previewScrim85 = Color(0xD90B0D10); // .85
  static const Color previewScrim94 = Color(0xF00B0D10); // .94
  static const Color previewScrim30 = Color(0x4D0B0D10); // .30
  static const Color previewScrim80 = Color(0xCC0B0D10); // .80
  static const Color previewScrim55 = Color(0x8C0B0D10); // .55
}
