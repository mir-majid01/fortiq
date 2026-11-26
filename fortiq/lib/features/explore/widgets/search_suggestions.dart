import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/icons/fortiq_icons.dart';
import '../../../core/widgets/state_scope.dart';

/// Live search suggestions (base names + creators) under the search field.
class SearchSuggestions extends StatelessWidget {
  const SearchSuggestions({
    super.key,
    required this.query,
    required this.maxHeight,
  });

  final String query;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final suggestions = state.searchSuggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: AppColors.surface,
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(4),
          physics: const ClampingScrollPhysics(),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final suggestion = suggestions[i];
            return Semantics(
              button: true,
              label: suggestion,
              child: InkWell(
                onTap: () => state.setSearch(suggestion),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      FortiqIcon(
                        FortiqIcons.search,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: AppTypography.resultName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
