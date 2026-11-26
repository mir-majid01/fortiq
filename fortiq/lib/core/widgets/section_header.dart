import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'expanded_tap_area.dart';

/// Section title row ("Categories", "Trending", "Recently added"):
/// Manrope 17/700 title + optional page dots + gold "View all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.dots,
    this.dotsKey,
    this.activeDot = 0,
  });

  final String title;
  final VoidCallback? onViewAll;

  /// Page-dot count (Trending uses 3 dots, first active).
  final int? dots;
  final Key? dotsKey;
  final int activeDot;

  @override
  Widget build(BuildContext context) {
    final viewAll = onViewAll == null
        ? null
        : Semantics(
            key: ValueKey('section-view-all-$title'),
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'View all $title',
            child: GestureDetector(
              onTap: onViewAll,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('View all', style: AppTypography.sectionAction),
              ),
            ),
          );
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(title, style: AppTypography.sectionTitle),
          const Spacer(),
          if (dots != null) ...[
            Semantics(
              key: dotsKey,
              container: true,
              excludeSemantics: true,
              label: 'Page ${activeDot + 1} of $dots',
              child: Row(
                children: [
                  for (var i = 0; i < dots!; i++)
                    Container(
                      width: i == activeDot ? 14 : 4,
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i == activeDot
                            ? AppColors.gold
                            : AppColors.chipInactive,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (viewAll != null) viewAll,
        ],
      ),
    );
    if (viewAll == null) return header;
    return ExpandedTapArea(
      padding: const EdgeInsets.only(top: 22, bottom: 5),
      child: header,
    );
  }
}
