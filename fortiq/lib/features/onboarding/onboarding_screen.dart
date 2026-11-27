import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_emblem.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/buttons.dart';
import '../../features/base_preview/base_preview.dart';

/// One onboarding page.
class _OnboardingPage {
  const _OnboardingPage({
    required this.kicker,
    required this.title,
    required this.body,
    required this.frontSeed,
    required this.frontHall,
    required this.frontName,
    required this.frontMeta,
    required this.backSeed,
  });

  final String kicker, title, body, frontHall, frontName, frontMeta;
  final int frontSeed, backSeed;
}

/// Page 1 preserves the approved reference. Pages 2–3 use the same layout
/// with product-accurate copy and clearly labelled sample artwork.
const List<_OnboardingPage> _pages = [
  _OnboardingPage(
    kicker: 'DISCOVER BASES',
    title: 'The right layout for every Town Hall',
    body:
        'Home Village and Builder Base layouts, sorted by level, purpose and style.',
    frontSeed: 3,
    frontHall: 'TH 17',
    frontName: 'Obsidian Ring',
    frontMeta: 'War · Anti 3 Star · Sample layout',
    backSeed: 6,
  ),
  _OnboardingPage(
    kicker: 'STAY CURRENT',
    title: 'Fresh layouts for every meta shift',
    body:
        'Save the layouts you trust, compare their source details, and keep your own imported bases ready for the next attack.',
    frontSeed: 11,
    frontHall: 'TH 15',
    frontName: 'Ashfall Core',
    frontMeta: 'Trophy · Sample layout',
    backSeed: 8,
  ),
  _OnboardingPage(
    kicker: 'COPY WITH CONFIDENCE',
    title: 'From Fortiq straight into your village',
    body:
        'Import an official layout link with your own preview, then open the unchanged link in Clash of Clans whenever you are ready.',
    frontSeed: 5,
    frontHall: 'TH 16',
    frontName: 'Hollow Crown',
    frontMeta: 'Legend League · Sample layout',
    backSeed: 14,
  ),
];

/// Onboarding: brand header with Skip, two stacked preview cards, kicker /
/// headline / body copy, page dots and the Continue button.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  /// Called when the flow completes or is skipped.
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onFinished();
    } else {
      setState(() => _page++);
    }
  }

  // Reference geometry on the 390×844 artboard: header 56–96, card stack
  // 132–492, copy from 540, dots 720, button 746–800.
  static const double _topInset = 12; // + status bar = 56
  static const double _gapAboveStack = 36;
  static const double _stackHeight = 360;
  static const double _backHeight = 340; // back card, top-aligned
  static const double _frontHeight = 342; // front card, bottom-aligned
  static const double _buttonBottom = 44;

  /// Below this safe height the pinned layout would squeeze the cards too
  /// far, so the page scrolls instead.
  static const double _scrollThreshold = 600;

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, viewport) => viewport.maxHeight < _scrollThreshold
              ? _scrollingLayout(page, viewport.maxWidth)
              : _pinnedLayout(page),
        ),
      ),
    );
  }

  /// The reference layout: cards pinned under the header, copy and button
  /// pinned to the bottom. The card stack takes the space in between (up to
  /// the reference height) and is the first thing to shrink on shorter
  /// screens.
  Widget _pinnedLayout(_OnboardingPage page) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _topInset),
        _header(),
        const SizedBox(height: _gapAboveStack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _stackHeight),
              child: _cardStack(page, height: double.infinity),
            ),
          ),
        ),
        _copy(page),
        const SizedBox(height: 32),
        _cta(),
      ],
    );
  }

  /// Very short screens: the same blocks in a scrollable column.
  List<Widget> _scrollingBlocks(_OnboardingPage page) => [
        const SizedBox(height: _topInset),
        _header(),
        const SizedBox(height: _gapAboveStack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: _cardStack(page, height: 280),
        ),
        const SizedBox(height: 48),
        _copy(page),
        const SizedBox(height: 40),
        _cta(),
      ];

  Widget _scrollingLayout(_OnboardingPage page, double width) {
    return ListView(
      padding: EdgeInsets.only(
        right: math.max(0, (width - 480) / 2), // keeps copy readable on tablets
        left: math.max(0, (width - 480) / 2),
      ),
      children: _scrollingBlocks(page),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const FortiqEmblem(width: 22, height: 28),
          const SizedBox(width: 8),
          Text('FORTIQ', style: AppTypography.brand(14)),
          const Spacer(),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: widget.onFinished,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Skip', style: AppTypography.skipLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Back card at half opacity, front card 18px lower — both sized as a
  /// fraction of [height] so the stack keeps the reference proportions at
  /// any size.
  Widget _cardStack(_OnboardingPage page, {required double height}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Back card: 340 of 360 tall, inset 14 on each side.
          FractionallySizedBox(
            alignment: Alignment.topCenter,
            heightFactor: _backHeight / _stackHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Opacity(
                opacity: 0.5,
                child: _PreviewCard(
                  seed: page.backSeed,
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
          ),
          // Front card: bottom-aligned, 342 of 360 tall.
          FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: _frontHeight / _stackHeight,
            child: _PreviewCard(
              seed: page.frontSeed,
              border: Border.all(color: AppColors.borderEmphasis),
              badge: page.frontHall,
              name: page.frontName,
              meta: page.frontMeta,
            ),
          ),
        ],
      ),
    );
  }

  Widget _copy(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(page.kicker, style: AppTypography.onboardingKicker),
          const SizedBox(height: 10),
          Text(page.title, style: AppTypography.onboardingTitle),
          const SizedBox(height: 10),
          Text(page.body, style: AppTypography.onboardingBody),
        ],
      ),
    );
  }

  /// Page dots and the Continue button, [_buttonBottom] above the bottom
  /// edge (or above the system safe inset when that is larger).
  Widget _cta() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: _buttonBottom),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _dots(),
            const SizedBox(height: 22),
            PrimaryButton(label: 'Continue', onTap: _next),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      children: [
        for (var i = 0; i < _pages.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: i == _page ? 24 : 6,
            height: 4,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i == _page ? AppColors.gold : AppColors.chipInactive,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// A rounded base-preview card with the reference scrim, hall badge and
/// title block.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.seed,
    required this.border,
    this.badge,
    this.name,
    this.meta,
  });

  final int seed;
  final Border border;
  final String? badge, name, meta;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: radius,
        border: border,
      ),
      child: ClipRRect(
        borderRadius: radius.subtract(
          const BorderRadius.all(Radius.circular(1)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BasePreview(seed: seed),
            if (name != null)
              const PreviewScrim(
                colors: [
                  AppColors.previewScrim30,
                  Colors.transparent,
                  AppColors.previewScrim85,
                ],
                stops: [0.0, 0.25, 1.0],
              ),
            if (badge != null)
              Positioned(left: 12, top: 12, child: HallBadge(label: badge!)),
            if (name != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.featuredTitle
                          .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.featuredSubtle,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
