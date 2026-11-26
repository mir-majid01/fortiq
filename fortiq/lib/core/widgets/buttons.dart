import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'expanded_tap_area.dart';

/// Gold call-to-action (`#D6A84F` fill, `#14100A` label) used by the
/// reference: Onboarding "Continue" (h54 r12 16/700), featured "Open in Game"
/// (h44 r12 14/700), Detail "Open in Game" (h54 r12 16/700), Filters
/// "Show Results" (h52 r12 15/700).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 54,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool expanded;

  TextStyle get _style {
    if (height >= 54) return AppTypography.buttonLarge;
    if (height >= 52) {
      return AppTypography.buttonReset.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.onGold);
    }
    return AppTypography.buttonMedium;
  }

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      child: Material(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: _style, maxLines: 1),
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Outlined ghost button (Filters "Reset": h52 px22 r12, 1px white .14).
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderAction),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            child: Text(label, style: AppTypography.buttonReset, maxLines: 1),
          ),
        ),
      ),
    );
  }
}

/// Compact icon button used over previews and in headers
/// (30–40px square, rgba(11,13,16,.8) fill, radius 9–12).
///
/// [label] is required — every icon-only control announces its purpose to
/// screen readers, and the touch target is padded to 44×44 without changing
/// the visual size.
class OverlayIconButton extends StatelessWidget {
  const OverlayIconButton({
    super.key,
    required this.child,
    required this.label,
    this.onTap,
    this.size = 34,
    this.borderRadius = 10,
    this.color = AppColors.badgeBackdrop,
  });

  final Widget child;

  /// Accessibility label, e.g. "Back" or "Share base".
  final String label;

  final VoidCallback? onTap;
  final double size;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExpandedTapArea.toTarget(
      size: size,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
