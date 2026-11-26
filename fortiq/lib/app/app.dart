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

/// Root widget: splash → onboarding → tabbed main shell, cross-faded.
class FortiqApp extends StatefulWidget {
  const FortiqApp({super.key});

  @override
  State<FortiqApp> createState() => _FortiqAppState();
}

enum _Phase { splash, onboarding, main }

class _FortiqAppState extends State<FortiqApp> {
  final AppState _state = AppState();
  _Phase _phase = _Phase.splash;

  @override
  void initState() {
    super.initState();
    // Loads behind the splash so the catalogue is ready for Home.
    _state.load();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
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
                  onDone: () => _to(_Phase.onboarding),
                ),
              _Phase.onboarding => OnboardingScreen(
                  onFinished: () {
                    _state.onboarded = true;
                    _to(_Phase.main);
                  },
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
