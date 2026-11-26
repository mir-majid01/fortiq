import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/router.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/app/tabs.dart';
import 'package:fortiq/core/storage/local_store.dart';
import 'package:fortiq/core/widgets/app_bottom_nav.dart';
import 'package:fortiq/core/widgets/badges.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/core/widgets/tab_page.dart';
import 'package:fortiq/features/collections/collections_screen.dart';
import 'package:fortiq/features/shared/placeholder_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _screenSize = Size(390, 844);
const _safeAreaInsets = FakeViewPadding(top: 24, bottom: 40);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const fonts = <String, List<String>>{
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
    for (final font in fonts.entries) {
      final loader = FontLoader(font.key);
      for (final path in font.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const shellCases = <({
    String name,
    Widget screen,
    int tabIndex,
    bool load,
    int favourites,
  })>[
    (
      name: 'empty Collections',
      screen: CollectionsScreen(),
      tabIndex: AppTab.collections,
      load: false,
      favourites: 0,
    ),
    (
      name: 'populated Collections',
      screen: CollectionsScreen(),
      tabIndex: AppTab.collections,
      load: true,
      favourites: 12,
    ),
    (
      name: 'shared placeholder',
      screen: PlaceholderTab(
        title: 'Coming soon',
        message: 'This feature is not available yet.',
      ),
      tabIndex: AppTab.collections,
      load: false,
      favourites: 0,
    ),
  ];

  for (final testCase in shellCases) {
    testWidgets('${testCase.name} has exactly one shared tab shell',
        (tester) async {
      await _pumpHost(
        tester,
        (_) => testCase.screen,
        tabIndex: testCase.tabIndex,
        load: testCase.load,
        favourites: testCase.favourites,
      );

      final page = find.byType(TabPage);
      expect(page, findsOneWidget,
          reason: 'The screen must delegate its scaffold to TabPage');
      expect(find.byType(Scaffold), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).resizeToAvoidBottomInset,
        isNot(false),
        reason: 'Tab scaffolds must keep keyboard resizing enabled',
      );

      final nav = find.byType(AppBottomNav);
      expect(nav, findsOneWidget,
          reason: 'A second local nav would duplicate tab navigation');
      expect(find.descendant(of: page, matching: nav), findsOneWidget);
      expect(tester.widget<AppBottomNav>(nav).currentIndex, testCase.tabIndex);
    });
  }

  testWidgets('Collections clears the nav above a safe-area inset',
      (tester) async {
    final state = await _pumpHost(
      tester,
      (_) => const CollectionsScreen(),
      tabIndex: AppTab.collections,
      favourites: 12,
    );
    final lastName = state.favoriteBases.last.name;

    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    final list = tester.widget<ListView>(listFinder);
    expect(
      list.padding,
      const EdgeInsets.fromLTRB(20, 0, 20, 132),
      reason: '68px nav + 40px safe inset + 24px breathing room',
    );

    final navRect = tester.getRect(find.byType(AppBottomNav));
    await tester.drag(listFinder, const Offset(0, -3000));
    await tester.pumpAndSettle();

    final lastCard = find.ancestor(
      of: find.text(lastName),
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxHeight == 88,
      ),
    );
    expect(lastCard, findsOneWidget);
    expect(
      tester.getRect(lastCard).bottom,
      lessThanOrEqualTo(navRect.top - 24),
      reason: 'The final card must remain clear of the floating nav',
    );
  });

  testWidgets('Collections shows and removes an unavailable saved ID',
      (tester) async {
    final state = await _pumpHost(
      tester,
      (_) => const CollectionsScreen(),
      tabIndex: AppTab.collections,
      storedFavourites: ['obsidian-ring', 'retired-base'],
    );

    expect(state.isFavorite('retired-base'), isTrue);
    expect(find.text('Obsidian Ring'), findsOneWidget);
    expect(find.byType(PlaceholderTab), findsNothing);
    final unavailable = find.byKey(
      const ValueKey<String>('collections-unavailable-retired-base'),
    );
    expect(unavailable, findsOneWidget);
    expect(
      find.descendant(of: unavailable, matching: find.text('Unavailable base')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: unavailable,
        matching: find.text('Saved ID: retired-base'),
      ),
      findsOneWidget,
    );

    final remove = find.descendant(
      of: unavailable,
      matching: find.byType(HeartButton),
    );
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect(unavailable, findsNothing);
    expect(state.isFavorite('retired-base'), isFalse);
    expect(find.text('Obsidian Ring'), findsOneWidget);
    expect(await LocalStore().loadFavouriteIds(), ['obsidian-ring']);
  });

  testWidgets('a stale-only Collections is not mistaken for an empty list',
      (tester) async {
    await _pumpHost(
      tester,
      (_) => const CollectionsScreen(),
      tabIndex: AppTab.collections,
      storedFavourites: ['retired-base'],
    );

    expect(find.byType(PlaceholderTab), findsNothing);
    expect(
      find.byKey(
          const ValueKey<String>('collections-unavailable-retired-base')),
      findsOneWidget,
    );
  });

  testWidgets('Collections scroll state survives IndexedStack tab switches',
      (tester) async {
    final state = await _pumpHost(
      tester,
      (state) => MainShell(
        listenable: state,
        tabIndex: () => state.tabIndex,
      ),
      tabIndex: AppTab.collections,
      favourites: 12,
    );

    expect(find.byType(IndexedStack), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byType(CollectionsScreen),
      matching: find.byType(Scrollable),
    );
    final scrollState = tester.state<ScrollableState>(scrollable);
    await tester.drag(scrollable, const Offset(0, -320));
    await tester.pumpAndSettle();
    final offset = scrollState.position.pixels;
    expect(offset, greaterThan(0));

    await tester.tap(find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Home'),
    ));
    await tester.pumpAndSettle();
    expect(state.tabIndex, AppTab.home);

    await tester.tap(find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Collections'),
    ));
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(scrollable), same(scrollState));
    expect(scrollState.position.pixels, closeTo(offset, 0.01));
    expect(
      find.descendant(
        of: find.byType(CollectionsScreen),
        matching: find.byType(TabPage),
      ),
      findsOneWidget,
    );
  });
}

Future<AppState> _pumpHost(
  WidgetTester tester,
  Widget Function(AppState state) builder, {
  int tabIndex = 0,
  bool load = true,
  int favourites = 0,
  List<String> storedFavourites = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screenSize;
  tester.view.padding = _safeAreaInsets;
  tester.view.viewPadding = _safeAreaInsets;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (storedFavourites.isNotEmpty)
      LocalStore.favouriteIdsKey: storedFavourites,
  });
  final state = AppState();
  addTearDown(state.dispose);
  await tester.runAsync(state.loadPersistedState);
  if (load) await state.load();
  state.tabIndex = tabIndex;
  for (final base in state.bases.take(favourites)) {
    await Future<void>.sync(() => state.toggleFavorite(base.id));
  }

  await tester.pumpWidget(
    StateScope(
      state: state,
      child: MaterialApp(
        theme: buildFortiqTheme(),
        home: builder(state),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}
