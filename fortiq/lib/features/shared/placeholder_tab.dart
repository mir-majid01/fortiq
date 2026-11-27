import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_emblem.dart';
import '../../core/widgets/tab_page.dart';

/// Honest empty state for tabs without saved content yet.
class CatalogueLoading extends StatelessWidget {
  const CatalogueLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading bases',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text('Loading bases…', style: AppTypography.screenTitle),
            const SizedBox(height: 6),
            Text(
              'Fetching rights-cleared layouts…',
              style: AppTypography.cardSubtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return TabPage(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FortiqEmblem(width: 46, height: 59),
                const SizedBox(height: 18),
                Text(title, style: AppTypography.screenTitle),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: AppTypography.cardSubtitle.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
