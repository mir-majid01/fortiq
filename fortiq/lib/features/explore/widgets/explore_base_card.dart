import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/icons/fortiq_icons.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/state_scope.dart';
import '../../../data/models/base_layout.dart';
import '../../base_preview/base_preview.dart';

/// Explore grid card: 166px preview (h scaled by grid), TH badge, heart,
/// name + category, star rating.
class ExploreBaseCard extends StatelessWidget {
  const ExploreBaseCard({super.key, required this.base, this.onTap});

  final BaseLayout base;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final favorited = state.isFavorite(base.id);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BasePreview(seed: base.previewSeed),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: HallBadge(label: base.hallBadge, compact: true),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: HeartButton(
                        key: Key('explore-favorite-${base.id}'),
                        favorited: favorited,
                        size: 30,
                        onTap: () =>
                            StateScope.toggleFavorite(context, base.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      base.name,
                      style: AppTypography.resultName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      base.categoriesLabel,
                      style: AppTypography.cardSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (base.rating != null)
                Row(
                  children: [
                    FortiqIcon(FortiqIcons.starFilled,
                        size: 11, filled: true, color: AppColors.gold),
                    const SizedBox(width: 3),
                    Text(
                      base.rating!.toStringAsFixed(1),
                      style: AppTypography.ratingLabel,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
