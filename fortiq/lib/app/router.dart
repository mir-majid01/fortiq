import 'package:flutter/material.dart';

import '../features/collections/collections_screen.dart';
import '../features/community/community_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';

/// Main shell: the five bottom-navigation destinations in an [IndexedStack],
/// so each tab keeps its scroll position and in-progress input while it is
/// switched away. Modal routes (Base Detail, expanded preview, filter sheet)
/// push on top of whichever tab is active.
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.listenable,
    required this.tabIndex,
  });

  /// Notified whenever app state changes; drives the active tab.
  final Listenable listenable;

  /// Reads the active tab index.
  final int Function() tabIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) => IndexedStack(
        index: tabIndex(),
        children: const [
          HomeScreen(),
          ExploreScreen(),
          CollectionsScreen(),
          CommunityScreen(),
          ProfileScreen(),
        ],
      ),
    );
  }
}
