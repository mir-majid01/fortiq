import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_icons.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/state_scope.dart';
import '../../core/widgets/tab_page.dart';
import '../../data/models/base_layout.dart';
import '../base_detail/base_detail_screen.dart';
import '../base_preview/base_preview.dart';
import '../shared/placeholder_tab.dart';

/// Collections — saved (favourited) bases. Real content: every heart tapped
/// anywhere in the app lands here. Saved IDs absent from the loaded catalogue
/// remain visible so they can be removed explicitly.
class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final savedIds = state.favoriteIds.toList(growable: false);
    if (savedIds.isEmpty) {
      return const PlaceholderTab(
        title: 'Collections',
        message: 'Tap the heart on any base to save it here for later.',
      );
    }
    return TabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Collections', style: AppTypography.screenTitle),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                TabPage.contentBottomPadding(context),
              ),
              itemCount: savedIds.length,
              itemBuilder: (context, i) {
                final id = savedIds[i];
                final base = state.baseById(id);
                return base == null
                    ? _UnavailableBaseCard(id: id)
                    : _SavedBaseCard(base: base);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedBaseCard extends StatelessWidget {
  const _SavedBaseCard({required this.base});

  final BaseLayout base;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('collections-base-${base.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () =>
              Navigator.of(context).push(BaseDetailScreen.route(base: base)),
          child: Container(
            height: 88,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(base.name,
                          style: AppTypography.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        '${base.hallBadge} · ${base.categoriesLabel}',
                        style: AppTypography.cardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _UnavailableBaseCard extends StatelessWidget {
  const _UnavailableBaseCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey<String>('collections-unavailable-$id'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: FortiqIcon(
                    FortiqIcons.navCollections,
                    size: 24,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Unavailable base', style: AppTypography.cardTitle),
                    const SizedBox(height: 3),
                    Text(
                      'Saved ID: $id',
                      style: AppTypography.cardSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              HeartButton(
                favorited: true,
                onTap: () => StateScope.toggleFavorite(context, id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
