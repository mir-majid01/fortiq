import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/widgets/state_scope.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import 'router.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// Status-bar / navigation-bar styling for the dark Fortiq canvas.
const SystemUiOverlayStyle fortiqSystemUi = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light, // Android
  statusBarBrightness: Brightness.dark, // iOS
  systemNavigationBarColor: AppColors.background,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// Root widget: splash → persisted onboarding/main route, cross-faded.
class FortiqApp extends StatefulWidget {
  const FortiqApp({super.key, this.state});

  /// Optional injection keeps one AppState owner in tests and embeddings.
  final AppState? state;

  @override
  State<FortiqApp> createState() => _FortiqAppState();
}

enum _Phase { splash, onboarding, main }

class _FortiqAppState extends State<FortiqApp> {
  late final AppState _state;
  late final bool _ownsState;
  _Phase _phase = _Phase.splash;
  late final Future<void> _restoration;

  @override
  void initState() {
    super.initState();
    _ownsState = widget.state == null;
    _state = widget.state ?? AppState();
    // Both loads run behind the splash; routing waits for restoration.
    // Handle read failures immediately so they cannot escape during the delay.
    _restoration = _state.loadPersistedState().onError(
      (Object error, StackTrace _) {
        if (mounted) {
          debugPrint('Fortiq: persisted state restore failed — $error');
        }
      },
    );
    _state.load();
  }

  @override
  void dispose() {
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  Future<void> _splashDone() async {
    await _restoration;
    if (!mounted) return;
    _to(_state.onboarded ? _Phase.main : _Phase.onboarding);
  }

  Future<void> _onboardingFinished() async {
    try {
      await _state.completeOnboarding();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not save your progress. Please try again.'),
        ),
      );
      debugPrint('Fortiq: onboarding persistence failed — $error');
      return;
    }
    if (!mounted) return;
    _to(_Phase.main);
  }

  void _to(_Phase phase) => setState(() => _phase = phase);

  @override
  Widget build(BuildContext context) {
    return StateScope(
      state: _state,
      child: MaterialApp(
        title: 'Fortiq',
        debugShowCheckedModeBanner: false,
        theme: buildFortiqTheme(),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: fortiqSystemUi,
          child: child ?? const SizedBox.shrink(),
        ),
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey<_Phase>(_phase),
            child: switch (_phase) {
              _Phase.splash => SplashScreen(
                  onDone: () => unawaited(_splashDone()),
                ),
              _Phase.onboarding => OnboardingScreen(
                  onFinished: () => unawaited(_onboardingFinished()),
                ),
              _Phase.main => MainShell(
                  listenable: _state,
                  tabIndex: () => _state.tabIndex,
                ),
            },
          ),
        ),
      ),
    );
  }
}
