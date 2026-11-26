import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';

/// Provides the [AppState] singleton to the widget tree.
class StateScope extends InheritedNotifier<AppState> {
  const StateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StateScope>();
    assert(scope != null, 'StateScope missing above ${context.widget}');
    return scope!.notifier!;
  }

  /// Runs a favourite edit and reports persistence failures without committing
  /// an optimistic UI state that LocalStore did not accept.
  static Future<void> toggleFavorite(BuildContext context, String id) async {
    try {
      await of(context).toggleFavorite(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not update saved bases. Please try again.'),
        ),
      );
    }
  }
}
