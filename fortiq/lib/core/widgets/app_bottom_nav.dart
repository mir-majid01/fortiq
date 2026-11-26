import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../icons/fortiq_icons.dart';

/// Floating pill bottom navigation from the Home/Explore references:
/// left/right 16, height 68, radius 20, rgba(23,28,35,.96) over a white .07
/// border; 5 items (22px icon, 11px label, 4px active dot).
///
/// It sits 28px above the bottom on a device without a system navigation
/// inset, and flush above the inset (home indicator / gesture bar) when there
/// is one, so it never collides with system UI.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double height = 68;

  /// Space between the nav and the screen bottom on devices with no system
  /// navigation inset.
  static const double restInset = 28;

  static double heightFor(BuildContext context) =>
      height +
      math.max(
        0,
        MediaQuery.textScalerOf(context).scale(11) - 11,
      );

  /// Vertical space the nav occupies from the screen bottom — scrollable
  /// content behind it should pad by this (plus breathing room).
  static double reservedBottom(BuildContext context) =>
      heightFor(context) +
      math.max(MediaQuery.paddingOf(context).bottom, restInset);

  static const List<(String, List<String>)> items = [
    ('Home', FortiqIcons.navHome),
    ('Explore', FortiqIcons.navExplore),
    ('Collections', FortiqIcons.navCollections),
    ('Community', FortiqIcons.navCommunity),
    ('Profile', FortiqIcons.navProfile),
  ];

  @override
  Widget build(BuildContext context) {
    final scaledLabel = MediaQuery.textScalerOf(context).scale(11);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: restInset),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: heightFor(context),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.navBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderNav),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scrollable =
                  scaledLabel > 11 || constraints.maxWidth < items.length * 60;
              final row = Row(
                mainAxisAlignment: scrollable
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _NavItem(
                      label: items[i].$1,
                      paths: items[i].$2,
                      selected: i == currentIndex,
                      onTap: () {
                        // Release the keyboard so it does not stay open over the
                        // tab the user just left.
                        FocusManager.instance.primaryFocus?.unfocus();
                        onTap(i);
                      },
                    ),
                ],
              );
              return scrollable
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: row,
                    )
                  : row;
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.paths,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<String> paths;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 60),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FortiqIcon(paths, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.navLabel.copyWith(color: color),
              ),
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.gold : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
