import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/app.dart';
import 'package:fortiq/app/router.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/app_bottom_nav.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/repositories/base_repository.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';
import 'package:fortiq/features/base_detail/base_detail_screen.dart';
import 'package:fortiq/features/explore/explore_screen.dart';
import 'package:fortiq/features/explore/widgets/search_suggestions.dart';
import 'package:fortiq/features/filters/filters_sheet.dart';
import 'package:fortiq/features/home/home_screen.dart';
import 'package:fortiq/features/onboarding/onboarding_screen.dart';
import 'package:fortiq/features/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
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
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });

  testWidgets('FortiqApp owns one restorable state and routes after splash',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FortiqApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    final scoped = StateScope.of(tester.element(find.byType(SplashScreen)));

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(StateScope.of(tester.element(find.byType(OnboardingScreen))),
        same(scoped));

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsOneWidget);
    expect(StateScope.of(tester.element(find.byType(MainShell))), same(scoped));
    expect(scoped.onboarded, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Splash shows brand, tagline and loading bar', (tester) async {
    var advanced = false;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onDone: () => advanced = true)),
    );
    expect(find.text('FORTIQ'), findsOneWidget);
    expect(find.text('BUILD. DEFEND. DOMINATE.'), findsOneWidget);

    // Auto-advance fires after 2s.
    await tester.pump(const Duration(seconds: 2));
    expect(advanced, isTrue);
  });

  testWidgets('Explore renders the sample count and quick chips',
      (tester) async {
    final state = AppState();
    await state.load();
    await tester.pumpWidget(
      StateScope(
        state: state,
        child:
            MaterialApp(theme: buildFortiqTheme(), home: const ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets); // title + nav label
    expect(find.text('86 bases'), findsOneWidget,
        reason: 'default Home Village view matches the reference count');
    expect(find.text('Top rated'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);

    // Design results visible: Obsidian Ring tops the grid.
    expect(find.text('Obsidian Ring'), findsWidgets);

    // Quick chips exist with the reference labels.
    expect(find.text('Home Village'), findsWidgets);
    expect(find.text('Builder Base'), findsOneWidget);
  });

  testWidgets('All chip shows both villages', (tester) async {
    final state = AppState();
    await state.load();
    await tester.pumpWidget(
      StateScope(
        state: state,
        child:
            MaterialApp(theme: buildFortiqTheme(), home: const ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(state.filters.village, isNull);
    expect(find.text('104 bases'), findsOneWidget);
  });

  testWidgets('Explore uses shared search state and suggestions update it',
      (tester) async {
    final state = AppState();
    await state.load();
    await tester.pumpWidget(
      StateScope(
        state: state,
        child:
            MaterialApp(theme: buildFortiqTheme(), home: const ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller, same(state.searchController));

    await tester.enterText(find.byType(TextField), 'obsidian');
    await tester.pump();
    expect(state.query, 'obsidian');

    await tester.tap(find.descendant(
      of: find.byType(SearchSuggestions),
      matching: find.text('Obsidian Ring'),
    ));
    await tester.pumpAndSettle();
    expect(state.searchController.text, 'Obsidian Ring');

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();
    expect(state.searchController.text, isEmpty);
  });

  testWidgets('Home Legend category opens matching Explore results',
      (tester) async {
    final state = AppState();
    await state.load();
    state.selectHallLevel(17);
    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(theme: buildFortiqTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final categoriesList = find.ancestor(
      of: find.text('Legend'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
    await tester.ensureVisible(find.text('Legend'));
    await tester.pumpAndSettle();
    await tester.drag(categoriesList, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legend'));
    await tester.pumpAndSettle();

    expect(state.tabIndex, 1);
    expect(state.filters.categories, {'Legend League'});
    expect(state.exploreResults, isNotEmpty);
    expect(
      state.exploreResults
          .every((base) => base.categories.contains('Legend League')),
      isTrue,
    );
  });

  test('Home handoff preserves search and scopes filters to the selection', () {
    final state = AppState();
    state.selectHallLevel(16);
    state.setSearch('obsidian');

    state.openExploreFromHome();

    expect(state.tabIndex, 1);
    expect(state.query, 'obsidian');
    expect(state.filters.village, Village.home);
    expect(state.filters.hallLevels, {16});
  });

  testWidgets('a catalogue failure offers a working retry', (tester) async {
    final repository = _FailingThenSampleRepository();
    final state = AppState(repository: repository);
    addTearDown(state.dispose);
    await state.load();
    await tester.pumpWidget(
      StateScope(
        state: state,
        child:
            MaterialApp(theme: buildFortiqTheme(), home: const ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('catalogue'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('catalogue'), findsNothing);
    expect(find.text('86 bases'), findsOneWidget);
  });

  testWidgets('search suggestions stay above the keyboard', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    final state = AppState();
    addTearDown(state.dispose);
    await state.load();
    await tester.pumpWidget(
      StateScope(
        state: state,
        child:
            MaterialApp(theme: buildFortiqTheme(), home: const ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    state.setSearch('a');
    await tester.pump();

    expect(tester.takeException(), isNull);
    final panel = tester.getRect(find.byType(SearchSuggestions));
    expect(panel.bottom, lessThanOrEqualTo(300));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('small phone large text keeps every shell tab operable',
      (tester) async {
    final state = await _loadedState(tester);
    await _pumpResponsiveApp(
      tester,
      state: state,
      child: MainShell(listenable: state, tabIndex: () => state.tabIndex),
      size: const Size(320, 568),
      textScale: 2,
      top: 24,
      bottom: 24,
    );

    const labels = ['Home', 'Explore', 'Collections', 'Community', 'Profile'];
    for (var index = 0; index < labels.length; index++) {
      state.tabIndex = index;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: labels[index]);

      final nav = find.byType(AppBottomNav);
      final visualNav = find.descendant(
        of: nav,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
      final navRect = tester.getRect(visualNav);
      expect(navRect.left, greaterThanOrEqualTo(0));
      expect(navRect.right, lessThanOrEqualTo(320));
      expect(navRect.bottom, lessThanOrEqualTo(568 - 24));

      final label =
          find.descendant(of: nav, matching: find.text(labels[index]));
      expect(label, findsOneWidget);
      await Scrollable.ensureVisible(tester.element(label));
      await tester.pumpAndSettle();
      expect(tester.getRect(label).left, greaterThanOrEqualTo(navRect.left));
      expect(tester.getRect(label).right, lessThanOrEqualTo(navRect.right));
      expect(_paragraph(tester, label).didExceedMaxLines, isFalse);
    }
  });

  testWidgets('landscape shell respects safe areas and scaled labels',
      (tester) async {
    final state = await _loadedState(tester);
    await _pumpResponsiveApp(
      tester,
      state: state,
      child: MainShell(listenable: state, tabIndex: () => state.tabIndex),
      size: const Size(844, 390),
      textScale: 1.5,
      top: 24,
      bottom: 20,
    );

    const labels = ['Home', 'Explore', 'Collections', 'Community', 'Profile'];
    for (var index = 0; index < labels.length; index++) {
      state.tabIndex = index;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: labels[index]);

      final visualNav = find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
      final navRect = tester.getRect(visualNav);
      expect(navRect.bottom, lessThanOrEqualTo(390 - 20));
      final label = find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text(labels[index]),
      );
      await Scrollable.ensureVisible(tester.element(label));
      await tester.pumpAndSettle();
      expect(_paragraph(tester, label).didExceedMaxLines, isFalse);
    }
  });

  testWidgets('short onboarding remains scrollable at large text',
      (tester) async {
    var finished = false;
    await _pumpResponsiveApp(
      tester,
      child: OnboardingScreen(onFinished: () => finished = true),
      size: const Size(320, 568),
      textScale: 2,
      top: 24,
      bottom: 24,
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
    final button = find.text('Continue');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Fresh layouts for every meta shift'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(finished, isFalse);
  });

  testWidgets('small detail keeps fixed actions readable at large text',
      (tester) async {
    final state = await _loadedState(tester);
    await _pumpResponsiveApp(
      tester,
      state: state,
      child: BaseDetailScreen(base: state.bases.first),
      size: const Size(320, 568),
      textScale: 2,
      top: 24,
      bottom: 24,
    );

    expect(tester.takeException(), isNull);
    final action = find.text('Open in Game');
    expect(_paragraph(tester, action).didExceedMaxLines, isFalse);
    final actionRect = tester.getRect(action);
    expect(actionRect.left, greaterThanOrEqualTo(20));
    expect(actionRect.right, lessThanOrEqualTo(320 - 74));
    expect(tester.getRect(find.bySemanticsLabel('Copy base link')).bottom,
        lessThanOrEqualTo(568 - 24));
  });

  testWidgets('compact filters keep all actions reachable at large text',
      (tester) async {
    final state = await _loadedState(tester);
    await _pumpResponsiveApp(
      tester,
      state: state,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const FiltersSheet(),
              ),
              child: const Text('Open filters'),
            ),
          ),
        ),
      ),
      size: const Size(320, 568),
      textScale: 2,
      top: 24,
      bottom: 24,
    );

    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final currentMeta = find.text('Current meta');
    await Scrollable.ensureVisible(tester.element(currentMeta));
    await tester.pumpAndSettle();
    expect(_paragraph(tester, currentMeta).didExceedMaxLines, isFalse);

    final results = find.text('Show Results');
    expect(tester.getRect(results).bottom, lessThanOrEqualTo(568 - 24));
    expect(_paragraph(tester, results).didExceedMaxLines, isFalse);
    await tester.tap(results);
    await tester.pumpAndSettle();
    expect(find.byType(FiltersSheet), findsNothing);
  });
}

Future<AppState> _loadedState(WidgetTester tester) async {
  final state = AppState();
  addTearDown(state.dispose);
  await state.load();
  return state;
}

Future<void> _pumpResponsiveApp(
  WidgetTester tester, {
  AppState? state,
  required Widget child,
  required Size size,
  double textScale = 1,
  double top = 0,
  double bottom = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    theme: buildFortiqTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: child,
  );
  await tester.pumpWidget(
    state == null ? app : StateScope(state: state, child: app),
  );
  await tester.pumpAndSettle();
}

RenderParagraph _paragraph(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder);

class _FailingThenSampleRepository implements BaseRepository {
  bool fail = true;

  @override
  Future<List<BaseLayout>> loadAll() async {
    if (fail) throw StateError('catalogue unavailable');
    return SampleBaseRepository().loadAll();
  }

  @override
  String? get featuredId => 'obsidian-ring';

  @override
  List<String> get trendingIds => const [];

  @override
  List<String> get recentIds => const [];
}
