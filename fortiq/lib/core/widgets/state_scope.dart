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
}
