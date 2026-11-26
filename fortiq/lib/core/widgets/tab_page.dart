import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'app_bottom_nav.dart';
import 'state_scope.dart';

/// Scaffold shared by the five bottom-navigation tabs: the tab's [child]
/// under the status bar, with the floating [AppBottomNav] pinned above the
/// system navigation area.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.child,
    this.resizeToAvoidBottomInset,
  });

  /// The tab content. Already inset below the status bar.
  final Widget child;

  /// Whether the on-screen keyboard shrinks the body.
  final bool? resizeToAvoidBottomInset;

  /// Bottom padding scrollable tab content needs so its last items clear the
  /// floating navigation.
  static double contentBottomPadding(BuildContext context) =>
      AppBottomNav.reservedBottom(context) + 24;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final loadError = state.loadError;
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: loadError == null
                  ? child
                  : Column(
                      children: [
                        _CatalogueErrorBanner(
                          message: loadError,
                          loading: state.isLoading,
                          onRetry: () => state.load(),
                        ),
                        Expanded(child: child),
                      ],
                    ),
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: TabNav()),
          ],
        ),
      ),
    );
  }
}

class _CatalogueErrorBanner extends StatelessWidget {
  const _CatalogueErrorBanner({
    required this.message,
    required this.loading,
    required this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(message, style: AppTypography.cardSubtitle),
              ),
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: loading ? null : onRetry,
                  child: Text(
                    loading ? 'Loading…' : 'Retry',
                    style: AppTypography.sectionAction.copyWith(fontSize: 14),
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

/// The bottom navigation bound to the active tab in [AppState].
class TabNav extends StatelessWidget {
  const TabNav({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    return AppBottomNav(
      currentIndex: state.tabIndex,
      onTap: (i) => state.tabIndex = i,
    );
  }
}
