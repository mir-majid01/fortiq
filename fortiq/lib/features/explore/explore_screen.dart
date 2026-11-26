import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils;

import '../../app/state/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_emblem.dart';
import '../../core/icons/fortiq_icons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/expanded_tap_area.dart';
import '../../core/widgets/tab_page.dart';
import '../../core/widgets/state_scope.dart';
import '../../data/models/base_layout.dart';
import '../../data/models/filters.dart';
import '../base_detail/base_detail_screen.dart';
import '../filters/filters_sheet.dart';
import 'widgets/explore_base_card.dart';
import 'widgets/search_suggestions.dart';

/// Explore — search, quick chips, results count, sort + filters controls,
/// responsive 2-column base grid.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim.withValues(alpha: 0.86),
      builder: (_) => const FiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);

    return TabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Explore', style: AppTypography.screenTitle),
          ),
          const SizedBox(height: 14),
          _SearchField(controller: state.searchController),
          const SizedBox(height: 9),
          const _QuickChips(),
          const SizedBox(height: 9),
          _ResultToolbar(onFilters: () => _openFilters(context)),
          const SizedBox(height: 12),
          const Expanded(child: _ResultsGrid()),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _suggestions = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _suggestions.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _suggestions,
      overlayChildBuilder: (context, info) {
        if (state.query.isEmpty || state.searchSuggestions.isEmpty) {
          return const SizedBox.shrink();
        }
        final field = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        final keyboardTop =
            info.overlaySize.height - MediaQuery.viewInsetsOf(context).bottom;
        final availableHeight = keyboardTop -
            TabPage.contentBottomPadding(context) -
            field.bottom -
            8;
        if (availableHeight < 44) return const SizedBox.shrink();

        return Positioned(
          left: field.left,
          top: field.bottom + 8,
          width: field.width,
          child: SearchSuggestions(
            query: state.query,
            maxHeight: math.min(availableHeight, 292),
          ),
        );
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            FortiqIcon(FortiqIcons.search,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                style: AppTypography.searchField,
                onChanged: state.setQuery,
                textInputAction: TextInputAction.search,
                cursorColor: AppColors.gold,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintMaxLines: 1,
                  hintStyle: AppTypography.searchHint,
                  hintText: 'Search bases, creators, tags',
                  suffixIcon: state.query.isEmpty
                      ? null
                      : ExpandedTapArea.toTarget(
                          size: 16,
                          child: GestureDetector(
                            key: const Key('search-clear'),
                            behavior: HitTestBehavior.opaque,
                            onTap: state.clearSearch,
                            child: Semantics(
                              label: 'Clear search',
                              button: true,
                              child: FortiqIcon(
                                FortiqIcons.close,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  const _QuickChips();

  static const List<String> _labels = [
    'All',
    'Home Village',
    'Builder Base',
    'War',
    'Farming',
    'Trophy',
    'Ranked',
    'Hybrid',
    'Anti 3 Star',
  ];

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = _labels[i];
          final selected = _isSelected(state, label);
          return Center(
            child: PillChip(
              label: label,
              selected: selected,
              onTap: () => _select(context, state, label, selected),
            ),
          );
        },
      ),
    );
  }

  static bool _isSelected(AppState state, String label) {
    switch (label) {
      case 'All':
        return state.filters.village == null;
      case 'Home Village':
        return state.filters.village == Village.home;
      case 'Builder Base':
        return state.filters.village == Village.builder;
      default:
        return state.filters.categories.contains(label);
    }
  }

  static void _select(
      BuildContext context, AppState state, String label, bool wasSelected) {
    switch (label) {
      case 'All':
        state.filters.village = null;
      case 'Home Village':
        state.filters.village = Village.home;
      case 'Builder Base':
        state.filters.village = Village.builder;
      default:
        wasSelected
            ? state.filters.categories.remove(label)
            : state.filters.categories.add(label);
    }
    state.notifyFilterChanged();
  }
}

class _ResultToolbar extends StatelessWidget {
  const _ResultToolbar({required this.onFilters});

  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final count = state.exploreResults.length;
    final activeFilters = state.filters.activeGroupCount;

    final countLabel = Text('$count bases', style: AppTypography.resultCount);
    final sortControl = Semantics(
      key: const Key('explore-sort'),
      container: true,
      excludeSemantics: true,
      button: true,
      label: 'Sort bases, ${state.sort.label}',
      child: PopupMenuButton<BaseSort>(
        color: AppColors.card,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        onSelected: state.setSort,
        itemBuilder: (_) => [
          for (final s in BaseSort.values)
            PopupMenuItem(
              value: s,
              child: Text(
                s.label,
                style: s == state.sort
                    ? AppTypography.chipUnselected.copyWith(
                        color: AppColors.gold, fontWeight: FontWeight.w700)
                    : AppTypography.chipUnselected,
              ),
            ),
        ],
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.sort.label, style: AppTypography.chipUnselected),
                  const SizedBox(width: 6),
                  FortiqIcon(
                    FortiqIcons.chevronDown,
                    size: 13,
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final filterControl = Semantics(
      key: const Key('explore-filters'),
      container: true,
      excludeSemantics: true,
      button: true,
      label: activeFilters == 0
          ? 'Filters'
          : 'Filters, $activeFilters active filter'
              '${activeFilters == 1 ? '' : 's'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onFilters,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FortiqIcon(
                    FortiqIcons.sliders,
                    size: 15,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 7),
                  Text('Filters', style: AppTypography.chipUnselected),
                  if (activeFilters > 0) ...[
                    const SizedBox(width: 7),
                    Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.goldWash18,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$activeFilters',
                        style: AppTypography.countBadge,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaledLabel = MediaQuery.textScalerOf(context).scale(13);
          final compact = constraints.maxWidth < 350 ||
              (scaledLabel > 18 && constraints.maxWidth < 600);
          if (!compact) {
            return Row(
              children: [
                countLabel,
                const Spacer(),
                sortControl,
                const SizedBox(width: 8),
                filterControl,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: countLabel),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [sortControl, filterControl],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid();

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final results = state.exploreResults;

    if (state.catalogueUnavailable) {
      return const _CatalogueUnavailable(
        key: Key('catalogue-unavailable'),
      );
    }
    if (results.isEmpty) {
      return _EmptyResults(query: state.query);
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        TabPage.contentBottomPadding(context),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 166 / 216, // preview + caption from the reference
      ),
      itemCount: results.length,
      itemBuilder: (context, i) => ExploreBaseCard(
        base: results[i],
        onTap: () => Navigator.of(context)
            .push(BaseDetailScreen.route(base: results[i])),
      ),
    );
  }
}

class _CatalogueUnavailable extends StatelessWidget {
  const _CatalogueUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FortiqEmblem(width: 46, height: 59),
            const SizedBox(height: 18),
            Text('Catalogue unavailable', style: AppTypography.screenTitle),
            const SizedBox(height: 8),
            Text(
              'No rights-cleared bases are available.',
              style: AppTypography.cardSubtitle.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FortiqIcon(FortiqIcons.search,
                size: 30, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(
              query.isEmpty ? 'No bases match these filters' : 'No bases found',
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              query.isEmpty
                  ? 'Try loosening a filter or two.'
                  : 'Nothing matched "$query". Try another search.',
              style: AppTypography.cardSubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                if (query.isNotEmpty) {
                  state.clearSearch();
                } else {
                  state.filters.reset();
                  state.notifyFilterChanged();
                }
              },
              child: Text(
                query.isEmpty ? 'Reset filters' : 'Clear search',
                style: AppTypography.sectionAction.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
