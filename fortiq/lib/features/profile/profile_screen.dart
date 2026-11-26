import 'package:flutter/material.dart';

import '../shared/placeholder_tab.dart';

/// Profile — the local Chief card. Account features require a backend and
/// are honestly stubbed (the design specifies only the nav entry).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderTab(
      title: 'Profile',
      message:
          'Sign-in and synced profiles arrive with a future update. '
          'Favourites, follows, and onboarding progress are kept for this '
          'session only and are not saved on this device.',
    );
  }
}
