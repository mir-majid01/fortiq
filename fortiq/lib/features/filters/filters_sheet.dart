import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_icons.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/expanded_tap_area.dart';
import '../../core/widgets/state_scope.dart';
import '../../data/models/base_layout.dart';
import '../../data/models/filters.dart';

/// The Filters bottom sheet: village, town hall, category, layout style,
/// freshness, verified toggle, Reset / Show Results. Edits a draft copy of
/// the filters; "Show Results" commits them to Explore.
class FiltersSheet extends StatefulWidget {
  const FiltersSheet({super.key});

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  ExploreFilters? _draft;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited lookups belong here, not initState.
    _draft ??= StateScope.of(context).filters.copy();
  }

  ExploreFilters get _d => _draft!;

  void _toggleSet(Set<String> set, String v) =>
      setState(() => set.contains(v) ? set.remove(v) : set.add(v));

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final village = _d.village ?? Village.home;
    final isHome = village == Village.home;
    final maxHall = village.maxHall;
    final hallCount = isHome ? 6 : 5;
    final sourceHalls = state.bases
        .where((base) => base.village == village && base.hallLevel != null)
        .map((base) => base.hallLevel!)
        .toSet();
    final halls = sourceHalls.isEmpty
        ? [for (var l = maxHall; l > maxHall - hallCount && l > 0; l--) l]
        : sourceHalls.toList()
      ..sort((a, b) => b.compareTo(a));
    final sourceCategories =
        state.bases.expand((base) => base.categories).toSet();
    final categories = [
      ...baseCategories.where(sourceCategories.contains),
      ...sourceCategories.where((value) => !baseCategories.contains(value)),
    ];
    final sourceStyles = state.bases
        .map((base) => base.layoutStyle)
        .where((value) => value.isNotEmpty)
        .toSet();
    final styles = sourceStyles.isEmpty
        ? const [
            'Box',
            'Diamond',
            'Ring',
            'Island',
            'Symmetrical',
            'Asymmetrical'
          ]
        : sourceStyles.toList()
      ..sort();

    return Container(
      // Reference: sheet starts 64px below the status-bar top.
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8 + kToolbarHeight,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle.
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.chipInactive,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Filters', style: AppTypography.filtersTitle),
                      const Spacer(),
                      _CloseButton(onTap: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Group(
                    label: 'VILLAGE',
                    child: SegmentedToggle(
                      options: const ['Home Village', 'Builder Base'],
                      selected: isHome ? 0 : 1,
                      onSelect: (i) => setState(() =>
                          _d.village = i == 0 ? Village.home : Village.builder),
                      containerColor: AppColors.card,
                      selectedColor: AppColors.segmentSelectedSheet,
                      showContainerBorder: false,
                    ),
                  ),
                  _Group(
                    label: isHome ? 'TOWN HALL' : 'BUILDER HALL',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final h in halls)
                          HallChip(
                            label: '${village.hallPrefix} $h',
                            selected: _d.hallLevels.contains(h),
                            width: 56,
                            height: 36,
                            onTap: () => setState(() =>
                                _d.hallLevels.contains(h)
                                    ? _d.hallLevels.remove(h)
                                    : _d.hallLevels.add(h)),
                          ),
                      ],
                    ),
                  ),
                  _Group(
                    label: 'CATEGORY',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories)
                          PillChip(
                            label: c,
                            selected: _d.categories.contains(c),
                            onTap: () => _toggleSet(_d.categories, c),
                          ),
                      ],
                    ),
                  ),
                  _Group(
                    label: 'LAYOUT STYLE',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in styles)
                          PillChip(
                            label: s,
                            selected: _d.styles.contains(s),
                            onTap: () => _toggleSet(_d.styles, s),
                          ),
                      ],
                    ),
                  ),
                  _Group(
                    label: 'FRESHNESS',
                    child: SegmentedToggle(
                      options: Freshness.values.map((f) => f.label).toList(),
                      selected: _d.freshness.index,
                      onSelect: (i) =>
                          setState(() => _d.freshness = Freshness.values[i]),
                      height: 36,
                      containerColor: AppColors.card,
                      selectedColor: AppColors.segmentSelectedSheet,
                      showContainerBorder: false,
                    ),
                  ),
                  if (state.bases.any((base) => base.creator.verified))
                    _VerifiedRow(
                      value: _d.verifiedOnly,
                      onChanged: (v) => setState(() => _d.verifiedOnly = v),
                    ),
                ],
              ),
            ),
          ),
          // Fixed action area. Keep the approved 30px visual spacing while
          // moving farther up the screen when the device has a bottom inset.
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 30),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  GhostButton(
                    label: 'Reset',
                    onTap: () => setState(() => _d.reset()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Show Results',
                      height: 52,
                      onTap: () {
                        state.applyFilters(_d);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.filterGroup),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _VerifiedRow extends StatelessWidget {
  const _VerifiedRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Verified builders only',
      toggled: value,
      enabled: true,
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            FortiqIcon(FortiqIcons.shieldCheck,
                size: 18, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Verified builders only',
                style: AppTypography.switchLabel,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
            ToggleSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('filters-close'),
      container: true,
      excludeSemantics: true,
      button: true,
      label: 'Close filters',
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: ExpandedTapArea.toTarget(
            size: 36,
            child: Material(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: FortiqIcon(
                      FortiqIcons.close,
                      size: 17,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
