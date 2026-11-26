import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/widgets/creator_avatar.dart';
import '../../core/widgets/expanded_tap_area.dart';
import '../../core/widgets/state_scope.dart';
import '../../core/widgets/tab_page.dart';
import '../shared/placeholder_tab.dart';

/// Community — the real creator directory from the loaded dataset with
/// follow state. Community features beyond that are honestly stubbed.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final creators = state.creators;
    if (creators.isEmpty) {
      return const PlaceholderTab(
        title: 'Community',
        message: 'Creator activity will appear here.',
      );
    }
    return TabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Community', style: AppTypography.screenTitle),
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
              itemCount: creators.length,
              itemBuilder: (context, i) {
                final creator = creators[i];
                final following = state.isFollowing(creator.name);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CreatorAvatar(initial: creator.initial),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            creator.name,
                            style: AppTypography.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ExpandedTapArea.toTarget(
                          size: 34,
                          child: Semantics(
                            key: ValueKey('community-follow-${creator.name}'),
                            container: true,
                            button: true,
                            selected: following,
                            label: following
                                ? 'Unfollow ${creator.name}'
                                : 'Follow ${creator.name}',
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => state.toggleFollow(creator.name),
                              child: Container(
                                height: 34,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: following
                                      ? Colors.transparent
                                      : AppColors.goldWash10,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: following
                                        ? AppColors.borderStrong
                                        : AppColors.gold,
                                  ),
                                ),
                                child: Text(
                                  following ? 'Following' : 'Follow',
                                  style: AppTypography.followLabel.copyWith(
                                    color: following
                                        ? AppColors.textSecondary
                                        : AppColors.gold,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
