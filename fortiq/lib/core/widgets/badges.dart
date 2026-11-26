import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../icons/fortiq_icons.dart';
import 'buttons.dart';

/// Hall badge shown over previews — featured/onboarding variant
/// (h26 px10 r7, 12/700 gold) and grid variant (h22 px8 r6, 11/700).
class HallBadge extends StatelessWidget {
  const HallBadge({super.key, required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 22 : 26,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.badgeBackdrop,
        borderRadius: BorderRadius.circular(compact ? 6 : 7),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: compact ? AppTypography.exploreBadge : AppTypography.hallBadge,
      ),
    );
  }
}

/// Heart favourite button over previews. Gold filled when active,
/// white outline otherwise — matches the reference states.
class HeartButton extends StatelessWidget {
  const HeartButton({
    super.key,
    required this.favorited,
    this.onTap,
    this.size = 34,
    double? borderRadius,
  }) : _borderRadius = borderRadius;

  final bool favorited;
  final VoidCallback? onTap;
  final double size;
  final double? _borderRadius;

  @override
  Widget build(BuildContext context) {
    final iconSize = size - 17.0; // 34→17, 32→15, 30→13
    return OverlayIconButton(
      label: favorited ? 'Remove from saved bases' : 'Save base',
      size: size,
      borderRadius: _borderRadius ?? (size >= 34 ? 10 : 9),
      onTap: onTap,
      child: FortiqIcon(
        FortiqIcons.heart,
        size: iconSize,
        color: favorited ? AppColors.gold : AppColors.textPrimary,
        filled: favorited,
      ),
    );
  }
}

/// Vertical gradient scrim over base previews (matches the reference stops).
class PreviewScrim extends StatelessWidget {
  const PreviewScrim({super.key, required this.colors, required this.stops});

  final List<Color> colors;
  final List<double> stops;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: stops,
          ),
        ),
      ),
    );
  }
}
