import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/filters.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';
import 'package:fortiq/features/base_detail/base_detail_screen.dart';
import 'package:fortiq/features/base_preview/base_preview.dart';
import 'package:fortiq/features/explore/explore_screen.dart';
import 'package:fortiq/features/filters/filters_sheet.dart';
import 'package:fortiq/features/home/home_screen.dart';
import 'package:fortiq/features/onboarding/onboarding_screen.dart';
import 'package:fortiq/features/splash/splash_screen.dart';

/// Captures reference-comparison renders of every screen at the design
/// artboard size (390×844).
///
/// Run:  flutter test test/goldens_test.dart --update-goldens
/// Output: test/goldens/*.png
void main() {
  testWidgets('capture screens', (tester) async {
    // Load the real bundled fonts so captures match the design.
    final fonts = <String, List<String>>{
      'Manrope': [
        'assets/fonts/Manrope-500.ttf',
        'assets/fonts/Manrope-600.ttf',
        'assets/fonts/Manrope-700.ttf',
        'assets/fonts/Manrope-800.ttf',
      ],
      'Inter': [
        'assets/fonts/Inter-400.ttf',
        'assets/fonts/Inter-500.ttf',
        'assets/fonts/Inter-600.ttf',
        'assets/fonts/Inter-700.ttf',
      ],
    };
    for (final entry in fonts.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value[0]))
        ..addFont(rootBundle.load(entry.value[1]))
        ..addFont(rootBundle.load(entry.value[2]))
        ..addFont(rootBundle.load(entry.value[3]));
      await loader.load();
    }

    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);
    await state.load();

    Future<void> snap(String name, Size size, Widget child) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    await snap('splash', const Size(390, 844), const SplashScreen());

    await snap(
      'onboarding',
      const Size(390, 844),
      OnboardingScreen(onFinished: () {}),
    );

    await snap('home_full', const Size(390, 1500), const HomeScreen());
    await snap('home_top', const Size(390, 844), const HomeScreen());

    // Scroll Home to the lower sections for the full-artboard comparison.
    await tester.drag(find.byType(ListView).first, const Offset(0, -640));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_scrolled.png'),
    );

    await snap('explore', const Size(390, 844), const ExploreScreen());

    await snap(
      'detail',
      const Size(390, 844),
      BaseDetailScreen(base: state.baseById('obsidian-ring')!),
    );

    await snap(
      'base_preview',
      const Size(240, 240),
      const ColoredBox(color: Color(0xFF273B20), child: BasePreview(seed: 3)),
    );

    // Match the selected state shown in the Filters reference.
    state.filters
      ..hallLevels = {17}
      ..categories = {'War', 'Anti 3 Star'}
      ..styles = {'Ring'}
      ..freshness = Freshness.sevenDays
      ..verifiedOnly = true;
    state.notifyFilterChanged();

    // Filters sheet over Explore.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(StateScope(
      state: state,
      child: MaterialApp(
        theme: buildFortiqTheme(),
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Scaffold(
            body: const ExploreScreen(),
            floatingActionButton: FloatingActionButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const FiltersSheet(),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/filters.png'),
    );
  });
}
