import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/game_actions.dart';
import '../../../core/widgets/state_scope.dart';
import '../../../data/models/base_layout.dart';
import '../../base_preview/base_preview.dart';

/// The 300px featured card: full-bleed preview, reference gradient scrim,
/// TH badge, save button, freshness line, title, creator, "Open in Game".
class FeaturedBaseCard extends StatelessWidget {
  const FeaturedBaseCard({super.key, required this.base, this.onTap});

  final BaseLayout base;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final favorited = state.isFavorite(base.id);

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                Positioned.fill(child: BasePreview(seed: base.previewSeed)),
                const Positioned.fill(
                  child: PreviewScrim(
                    colors: [
                      AppColors.previewScrim40,
                      Colors.transparent,
                      AppColors.previewScrim50,
                      AppColors.previewScrim94,
                    ],
                    stops: [0.0, 0.26, 0.58, 1.0],
                  ),
                ),
                Positioned(left: 12, top: 12, child: HallBadge(label: base.hallBadge)),
                Positioned(
                  right: 12,
                  top: 12,
                  child: HeartButton(
                    favorited: favorited,
                    onTap: () => state.toggleFavorite(base.id),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FreshnessLine(text: base.updatedText),
                            const SizedBox(height: 3),
                            Text(
                              base.name,
                              style: AppTypography.featuredTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              // The reference surfaces the distinctive tag
                              // ("Anti 3 Star · by Kaiden").
                              '${base.categories.last} · ${base.creatorHandle}',
                              style: AppTypography.featuredSubtle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      PrimaryButton(
                        label: 'Open in Game',
                        height: 44,
                        expanded: false,
                        onTap: () => GameActions.openInGame(context, base),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FreshnessLine extends StatelessWidget {
  const _FreshnessLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppTypography.freshnessLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
