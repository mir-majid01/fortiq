import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_emblem.dart';
import '../../core/icons/fortiq_icons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/tab_page.dart';
import '../../core/widgets/game_actions.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/state_scope.dart';
import '../../data/models/base_layout.dart';
import '../../features/base_preview/base_preview.dart';
import '../base_detail/base_detail_screen.dart';
import 'widgets/featured_base_card.dart';
import 'widgets/trending_card.dart';

/// Home — the approved "Main" screen: header, greeting, village + hall
/// selectors, featured base, categories, trending, recently added.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPage(
      child: ListView(
        padding: EdgeInsets.only(bottom: TabPage.contentBottomPadding(context)),
        children: [
          const SizedBox(height: 2),
          const _HomeHeader(),
          const SizedBox(height: 22),
          const _Greeting(),
          const SizedBox(height: 22),
          const _VillageAndHallSelectors(),
          const SizedBox(height: 19),
          const _FeaturedSection(),
          const _CategoriesSection(),
          const _TrendingSection(),
          const _RecentSection(),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const FortiqEmblem(width: 23, height: 29),
          const SizedBox(width: 8),
          Text('FORTIQ', style: AppTypography.brand(15)),
          const Spacer(),
          Semantics(
            key: const Key('home-notifications'),
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'Notifications, all caught up',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showNotificationsSheet(context),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: FortiqIcon(
                          FortiqIcons.bell,
                          size: 19,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good evening, Chief', style: AppTypography.greetingLabel),
          const SizedBox(height: 2),
          Text(state.greetingTitle, style: AppTypography.greetingTitle),
        ],
      ),
    );
  }
}

class _VillageAndHallSelectors extends StatelessWidget {
  const _VillageAndHallSelectors();

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final isHome = state.village == Village.home;
    final maxHall = state.village.maxHall;
    // Reference strip: TH 18 … TH 11 (top 8 levels for Home Village).
    final levels = [for (var l = maxHall; l > maxHall - 8 && l > 0; l--) l];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x0DFFFFFF)),
            ),
            child: Row(
              children: [
                _villageTab(
                  context,
                  label: 'Home Village',
                  selected: isHome,
                  onTap: () => state.selectVillage(Village.home),
                ),
                _villageTab(
                  context,
                  label: 'Builder Base',
                  selected: !isHome,
                  onTap: () => state.selectVillage(Village.builder),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: levels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final level = levels[i];
              return Center(
                child: HallChip(
                  label: '${state.village.hallPrefix} $level',
                  selected: level == state.hallLevel,
                  onTap: () => state.selectHallLevel(level),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _villageTab(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final key = ValueKey(
      'home-village-${label == 'Home Village' ? 'home' : 'builder'}',
    );
    return Expanded(
      child: Semantics(
        key: key,
        container: true,
        excludeSemantics: true,
        role: SemanticsRole.tab,
        selected: selected,
        label: label,
        onTap: onTap,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color:
                      selected ? AppColors.segmentSelected : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: selected
                      ? Border.all(color: AppColors.borderGoldSoft)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: AppTypography.chipUnselected.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final featured = state.featured;
    if (featured == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FeaturedBaseCard(
        base: featured,
        onTap: () => _openDetail(context, featured),
      ),
    );
  }
}

void _openDetail(BuildContext context, BaseLayout base) {
  Navigator.of(context).push(BaseDetailScreen.route(base: base));
}

class _SectionHeaderSlot extends StatelessWidget {
  const _SectionHeaderSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          Positioned(top: 22, left: 0, right: 0, child: child),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.name, required this.paths});

  final String name;
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          FortiqIcon(paths, size: 18, color: AppColors.gold),
          const SizedBox(width: 9),
          Text(name, style: AppTypography.categoryChip),
        ],
      ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection();

  static const List<(String, String, List<String>)> _cats = [
    ('War', 'War', FortiqIcons.war),
    ('CWL', 'CWL', FortiqIcons.cwl),
    ('Trophy', 'Trophy', FortiqIcons.trophy),
    ('Farming', 'Farming', FortiqIcons.farming),
    ('Hybrid', 'Hybrid', FortiqIcons.hybrid),
    ('Legend', 'Legend League', FortiqIcons.legend),
  ];

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeaderSlot(
          child: SectionHeader(
            title: 'Categories',
            onViewAll: () => state.openExploreFromHome(),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: _cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => Semantics(
              key: ValueKey('home-category-${_cats[i].$1}'),
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Explore ${_cats[i].$2} bases',
              child: GestureDetector(
                onTap: () => state.openExploreFromHome(category: _cats[i].$2),
                behavior: HitTestBehavior.opaque,
                child: _CategoryPill(name: _cats[i].$1, paths: _cats[i].$3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendingSection extends StatefulWidget {
  const _TrendingSection();

  @override
  State<_TrendingSection> createState() => _TrendingSectionState();
}

class _TrendingSectionState extends State<_TrendingSection> {
  final _scrollController = ScrollController();
  int _activeDot = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateActiveDot);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateActiveDot)
      ..dispose();
    super.dispose();
  }

  void _updateActiveDot() {
    if (!_scrollController.hasClients) return;
    final count = StateScope.of(context).trending.length;
    final page = (_scrollController.offset / 268).round().clamp(0, count - 1);
    if (page != _activeDot) setState(() => _activeDot = page);
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final trending = state.trending;
    if (trending.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _SectionHeaderSlot(
          child: SectionHeader(
            title: 'Trending',
            dots: trending.length,
            dotsKey: const Key('trending-position'),
            activeDot: _activeDot,
            onViewAll: () => state.openExploreFromHome(),
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 262, // 192 preview + 10 gap + 60 caption
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: trending.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => TrendingCard(
              base: trending[i],
              onTap: () => _openDetail(context, trending[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentItem extends StatelessWidget {
  const _RecentItem({required this.base});

  final BaseLayout base;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(context, base),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x0DFFFFFF)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: BasePreview(seed: base.previewSeed),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            base.name,
                            style: AppTypography.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${base.hallBadge} · ${base.categoriesLabel} · ${base.creatorHandle}',
                            style: AppTypography.cardSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(base.updatedText, style: AppTypography.cardTime),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SizedBox(width: 40, height: 40),
                  ],
                ),
              ),
              Positioned(
                right: 4,
                top: 22,
                child: Semantics(
                  key: ValueKey('home-recent-open-${base.id}'),
                  container: true,
                  excludeSemantics: true,
                  button: true,
                  label: 'Open ${base.name} in game',
                  onTap: () => GameActions.openInGame(context, base),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => GameActions.openInGame(context, base),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        children: [
                          Positioned(
                            right: 4,
                            top: 2,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Material(
                                color: AppColors.card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: AppColors.borderStrong,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () =>
                                      GameActions.openInGame(context, base),
                                  child: const Center(
                                    child: FortiqIcon(
                                      FortiqIcons.external,
                                      size: 17,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final recent = state.recent;
    if (recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderSlot(
            child: SectionHeader(
              title: 'Recently added',
              onViewAll: () => state.openExploreFromHome(),
            ),
          ),
          const SizedBox(height: 5),
          for (final base in recent) _RecentItem(base: base),
        ],
      ),
    );
  }
}
