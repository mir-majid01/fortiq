import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/state_scope.dart';
import '../../../data/models/base_layout.dart';
import '../../base_preview/base_preview.dart';

/// Trending carousel card: 256×192 preview, bottom scrim, TH badge, heart,
/// "12.4k copies" line, then name + category caption.
class TrendingCard extends StatelessWidget {
  const TrendingCard({super.key, required this.base, this.onTap});

  final BaseLayout base;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final favorited = state.isFavorite(base.id);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 256,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 192,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    Positioned.fill(child: BasePreview(seed: base.previewSeed)),
                    const Positioned.fill(
                      child: PreviewScrim(
                        colors: [Colors.transparent, AppColors.previewScrim80],
                        stops: [0.62, 1.0],
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: HallBadge(label: base.hallBadge, compact: true),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: HeartButton(
                        favorited: favorited,
                        size: 32,
                        onTap: () => state.toggleFavorite(base.id),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 9,
                      child: Text(
                        base.copiesLabel(),
                        style: AppTypography.copiesLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              base.name,
              style: AppTypography.cardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              base.categoriesLabel,
              style: AppTypography.cardSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
