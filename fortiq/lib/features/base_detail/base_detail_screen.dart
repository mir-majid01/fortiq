import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_icons.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/creator_avatar.dart';
import '../../core/widgets/game_actions.dart';
import '../../core/widgets/state_scope.dart';
import '../../data/models/base_layout.dart';
import '../base_preview/base_preview.dart';
import 'expanded_base_preview.dart';

/// Base detail — full-bleed 470px preview with top/bottom scrims, floating
/// back/share/favourite/zoom actions, metadata block, fixed bottom bar with
/// "Open in Game" + copy-link.
class BaseDetailScreen extends StatelessWidget {
  const BaseDetailScreen({super.key, required this.base});

  final BaseLayout base;

  static Route<void> route({required BaseLayout base}) => PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: BaseDetailScreen(base: base),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final favorited = state.isFavorite(base.id);
    final stats = <Widget>[
      if (base.rating != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FortiqIcon(FortiqIcons.starFilled,
                size: 12, filled: true, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(base.rating!.toStringAsFixed(1),
                style: AppTypography.statStrong),
          ],
        ),
      if (base.copies != null)
        Text(base.copiesLabel(), style: AppTypography.statLabel),
      if (base.updatedText != '—')
        Text(
          base.updatedLabel?.replaceFirst('New · ', 'Updated ') ??
              base.updatedText,
          style: AppTypography.statLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Preview + scrims + metadata.
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 470,
                    child: Stack(
                      children: [
                        Positioned.fill(
                            child: BasePreview(seed: base.previewSeed)),
                        const Positioned.fill(
                          child: PreviewScrim(
                            colors: [
                              AppColors.previewScrim55,
                              Colors.transparent,
                              Colors.transparent,
                              AppColors.background,
                            ],
                            stops: [0.0, 0.20, 0.66, 1.0],
                          ),
                        ),
                        // Zoom control — reference: right 20, top 396.
                        Positioned(
                          right: 20,
                          top: 396,
                          child: OverlayIconButton(
                            label: 'Zoom layout',
                            size: 36,
                            color: AppColors.controlBackdrop,
                            onTap: () => _openExpanded(context),
                            child: FortiqIcon(FortiqIcons.expand,
                                size: 16, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Metadata chips.
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _MetaChip(label: base.hallBadge, gold: true),
                            for (final c in base.categories)
                              _MetaChip(label: c),
                            if (base.layoutStyle.isNotEmpty)
                              _MetaChip(label: base.layoutStyle),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(base.name, style: AppTypography.detailTitle),
                        const SizedBox(height: 12),
                        // Creator attribution from the catalogue source.
                        Row(
                          children: [
                            CreatorAvatar(initial: base.creator.initial),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      base.sourceAttribution
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? 'Source: ${base.sourceAttribution}'
                                          : base.creator.name.trim().isEmpty
                                              ? 'Source unavailable'
                                              : base.creator.name,
                                      style: AppTypography.creatorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (base.creator.verified) ...[
                                    const SizedBox(width: 5),
                                    FortiqIcon(FortiqIcons.check,
                                        size: 13,
                                        strokeWidth: 2.2,
                                        color: AppColors.success),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (stats.isNotEmpty)
                          Row(
                            children: [
                              for (var i = 0; i < stats.length; i++) ...[
                                if (i > 0) const _StatDivider(),
                                if (i == stats.length - 1)
                                  Flexible(child: stats[i])
                                else
                                  stats[i],
                              ],
                            ],
                          ),
                        const SizedBox(height: 12),
                        if (base.verified)
                          _VerifiedLine(hall: base.hallFullName)
                        else
                          Text(
                            'Community layout · not independently verified',
                            style: AppTypography.verifiedLine,
                          ),
                        const SizedBox(height: 130),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Floating top actions (SafeArea top + 0, per reference 56px).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Row(
                    children: [
                      OverlayIconButton(
                        label: 'Back',
                        size: 40,
                        color: AppColors.controlBackdrop,
                        onTap: () => Navigator.of(context).pop(),
                        child: FortiqIcon(FortiqIcons.chevronLeft,
                            size: 20, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      Builder(
                        builder: (shareContext) => OverlayIconButton(
                          label: 'Share base',
                          size: 40,
                          color: AppColors.controlBackdrop,
                          onTap: () =>
                              GameActions.shareBase(shareContext, base),
                          child: FortiqIcon(FortiqIcons.share,
                              size: 18, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      HeartButton(
                        favorited: favorited,
                        size: 40,
                        borderRadius: 12,
                        onTap: () =>
                            StateScope.toggleFavorite(context, base.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Fixed bottom action bar.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background],
                    stops: [0.0, 0.30],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Open in Game',
                          height: 54,
                          onTap: () => GameActions.openInGame(context, base),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Semantics(
                        key: const Key('detail-copy'),
                        container: true,
                        button: true,
                        label: 'Copy base link',
                        child: Material(
                          color: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: AppColors.borderEmphasis),
                          ),
                          child: InkWell(
                            onTap: () => GameActions.copyLink(context, base),
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 54,
                              height: 54,
                              child: Center(
                                child: FortiqIcon(FortiqIcons.copy,
                                    size: 19, color: AppColors.textCardSubtle),
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
          ],
        ),
      ),
    );
  }

  void _openExpanded(BuildContext context) {
    Navigator.of(context).push(ExpandedBasePreview.route(
      seed: base.previewSeed,
      title: base.name,
    ));
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.gold = false});

  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: gold ? AppColors.goldWash12 : AppColors.card,
        borderRadius: BorderRadius.circular(6),
      ),
      // Row(min) keeps the chip hugging its label under Wrap constraints.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: gold
                ? AppTypography.detailChipActive
                : AppTypography.detailChip,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('|',
            style: AppTypography.statLabel
                .copyWith(color: AppColors.chipInactive)),
      );
}

class _VerifiedLine extends StatelessWidget {
  const _VerifiedLine({required this.hall});

  final String hall;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FortiqIcon(FortiqIcons.shieldCheck, size: 14, color: AppColors.success),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Verified for the current $hall update',
            style: AppTypography.verifiedLine,
          ),
        ),
      ],
    );
  }
}
