import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'expanded_tap_area.dart';

/// Rounded filter chip (Explore quick chips + Filters sheet category/style
/// pills: h34, px13-14, r999, 13/600).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ExpandedTapArea.toTarget(
      size: 34,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        button: true,
        selected: selected,
        enabled: onTap != null,
        label: label,
        onTap: onTap,
        child: Material(
          color: selected ? AppColors.goldWash10 : AppColors.card,
          shape: StadiumBorder(
            side:
                BorderSide(color: selected ? AppColors.gold : AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // Row(min) keeps the pill hugging its label even when the Wrap
              // offers bounded width (Container(alignment:) would stretch).
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.chipUnselected.copyWith(
                      color: selected ? AppColors.gold : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hall-level chip (Home strip: h38 px14 r10; Filters sheet: 56×36 r10).
/// 13/700 tabular numerals; selected = gold wash + gold border + gold text.
class HallChip extends StatelessWidget {
  const HallChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.width,
    this.height = 38,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: selected ? AppColors.goldWash10 : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? AppColors.gold : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: width == null ? 14 : 0),
          width: width,
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.chipSelected.copyWith(
              color: selected ? AppColors.gold : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
    return ExpandedTapArea.toTarget(
      size: height,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        button: true,
        selected: selected,
        enabled: onTap != null,
        label: label,
        onTap: onTap,
        child: width == null
            ? chip
            : SizedBox(width: width, height: height, child: chip),
      ),
    );
  }
}

/// Two/four-option segmented control (Village + Freshness selectors).
/// Mirrors the reference: 3px inset container, 9px radius segments.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.height = 38,
    this.containerColor = AppColors.surface,
    this.selectedColor = AppColors.segmentSelected,
    this.showContainerBorder = true,
    this.selectedFontWeight = FontWeight.w700,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;
  final Color containerColor;
  final Color selectedColor;
  final bool showContainerBorder;
  final FontWeight selectedFontWeight;

  @override
  Widget build(BuildContext context) {
    final inset = 3.0 + (showContainerBorder ? 1.0 : 0.0);
    final textScaler = MediaQuery.textScalerOf(context);
    return ExpandedTapArea.toTarget(
      size: height + inset * 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            maxLines: 1,
          );
          var widestLabel = 0.0;
          for (final option in options) {
            painter.text = TextSpan(
              text: option,
              style: AppTypography.chipUnselected,
            );
            painter.layout();
            widestLabel = math.max(widestLabel, painter.width);
          }
          painter.dispose();
          final optionWidth = options.isEmpty
              ? double.infinity
              : (constraints.maxWidth - inset * 2) / options.length;
          final scrollable = options.isNotEmpty && widestLabel > optionWidth;

          Widget segment(int i, {bool padded = false}) {
            return Semantics(
              key: ValueKey('segmented-option-$i'),
              container: true,
              excludeSemantics: true,
              role: SemanticsRole.tab,
              selected: i == selected,
              enabled: true,
              label: options[i],
              onTap: () => onSelect(i),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: scrollable ? () => onSelect(i) : null,
                child: Container(
                  height: height,
                  padding: EdgeInsets.symmetric(horizontal: padded ? 12 : 0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? selectedColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    options[i],
                    maxLines: 1,
                    style: (i == selected
                            ? AppTypography.chipSelected
                            : AppTypography.chipUnselected)
                        .copyWith(
                      fontWeight: i == selected
                          ? selectedFontWeight
                          : FontWeight.w600,
                      color: i == selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }

          final row = Row(
            mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
            children: [
              for (var i = 0; i < options.length; i++)
                if (scrollable)
                  segment(i, padded: true)
                else
                  Expanded(child: segment(i)),
            ],
          );
          return Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                  border: showContainerBorder
                      ? Border.all(color: AppColors.border)
                      : null,
                ),
                child: scrollable
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: row,
                      )
                    : row,
              ),
              if (options.isNotEmpty && !scrollable)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder: (context, constraints) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final contentWidth =
                              constraints.maxWidth - inset * 2;
                          if (contentWidth <= 0) return;
                          final width = contentWidth / options.length;
                          final index =
                              ((details.localPosition.dx - inset) / width)
                                  .floor()
                                  .clamp(0, options.length - 1)
                                  .toInt();
                          onSelect(index);
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The "Verified builders only" switch from the filter sheet
/// (44×26 track, 20×20 thumb, success green when on).
class ToggleSwitch extends StatelessWidget {
  const ToggleSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ExpandedTapArea.toTarget(
      size: 26,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        toggled: value,
        enabled: onChanged != null,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: GestureDetector(
          onTap: () => onChanged?.call(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 26,
            decoration: BoxDecoration(
              color: value ? AppColors.success : AppColors.chipInactive,
              borderRadius: BorderRadius.circular(13),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
