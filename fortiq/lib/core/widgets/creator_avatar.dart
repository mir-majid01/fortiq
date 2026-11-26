import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Circular initial avatar (Home header 40px, Detail creator 28px).
class CreatorAvatar extends StatelessWidget {
  const CreatorAvatar({
    super.key,
    required this.initial,
    this.size = 28,
    this.fontSize,
  });

  final String initial;
  final double size;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderEmphasis),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.avatarInitial(fontSize ?? (size > 34 ? 14 : 12)),
      ),
    );
  }
}
