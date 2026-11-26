import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/router.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/app_bottom_nav.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/core/widgets/tab_page.dart';
import 'package:fortiq/features/collections/collections_screen.dart';
import 'package:fortiq/features/community/community_screen.dart';
import 'package:fortiq/features/profile/profile_screen.dart';
import 'package:fortiq/features/shared/placeholder_tab.dart';

const _screenSize = Size(390, 844);
const _safeAreaInsets = FakeViewPadding(top: 24, bottom: 40);

void main() {
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
      tabIndex: 2,
      load: false,
      favourites: 0,
    ),
    (
      name: 'populated Collections',
      screen: CollectionsScreen(),
      tabIndex: 2,
      load: true,
      favourites: 12,
    ),
    (
      name: 'empty Community',
      screen: CommunityScreen(),
      tabIndex: 3,
      load: false,
      favourites: 0,
    ),
    (
      name: 'populated Community',
      screen: CommunityScreen(),
      tabIndex: 3,
      load: true,
      favourites: 0,
    ),
    (
      name: 'Profile',
      screen: ProfileScreen(),
      tabIndex: 4,
      load: false,
      favourites: 0,
    ),
    (
      name: 'shared placeholder',
      screen: PlaceholderTab(
        title: 'Coming soon',
        message: 'This feature is not available yet.',
      ),
      tabIndex: 3,
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

  const scrollCases = <({
    String name,
    Widget screen,
    int favourites,
    double cardHeight,
  })>[
    (
      name: 'Collections',
      screen: CollectionsScreen(),
      favourites: 12,
      cardHeight: 88,
    ),
    (
      name: 'Community',
      screen: CommunityScreen(),
      favourites: 0,
      cardHeight: 60,
    ),
  ];

  for (final testCase in scrollCases) {
    testWidgets('${testCase.name} clears the nav above a safe-area inset',
        (tester) async {
      final state = await _pumpHost(
        tester,
        (_) => testCase.screen,
        tabIndex: testCase.name == 'Collections' ? 2 : 3,
        favourites: testCase.favourites,
      );
      final lastName = testCase.favourites > 0
          ? state.favoriteBases.last.name
          : state.creators.last.name;

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
          (widget) =>
              widget is Container &&
              widget.constraints?.maxHeight == testCase.cardHeight,
        ),
      );
      expect(lastCard, findsOneWidget);
      expect(
        tester.getRect(lastCard).bottom,
        lessThanOrEqualTo(navRect.top - 24),
        reason: 'The final card must remain clear of the floating nav',
      );
    });
  }

  testWidgets('Profile describes favourites, follows and onboarding honestly',
      (tester) async {
    await _pumpHost(tester, (_) => const ProfileScreen(), tabIndex: 4);

    final message = find.textContaining('Sign-in and synced profiles');
    expect(message, findsOneWidget);
    final copy = tester.widget<Text>(message).data!.toLowerCase();
    for (final phrase in [
      'favourites',
      'follows',
      'onboarding',
      'session only',
      'not saved on this device',
    ]) {
      expect(copy, contains(phrase));
    }
    expect(copy, isNot(contains('stay on this device')));
  });

  testWidgets('Community follow controls expose state and a 44px hit target',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final state = await _pumpHost(
      tester,
      (_) => const CommunityScreen(),
      tabIndex: 3,
    );
    final creator = state.creators.first.name;
    final follow = find.byKey(ValueKey('community-follow-$creator'));

    expect(follow, findsOneWidget);
    var node = tester.getSemantics(follow);
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(node.label, 'Follow $creator');

    final visual = find.descendant(
      of: follow,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container && widget.constraints?.maxHeight == 34,
      ),
    );
    expect(visual, findsOneWidget);
    final visualRect = tester.getRect(visual);
    expect(visualRect.height, 34, reason: 'The approved visual size is unchanged');
    expect(visualRect.width, greaterThanOrEqualTo(44));

    // Four pixels above the visual is inside a 44px target, but outside the
    // original 34px-high button.
    await tester.tapAt(Offset(visualRect.center.dx, visualRect.top - 4));
    await tester.pumpAndSettle();

    expect(state.isFollowing(creator), isTrue);
    node = tester.getSemantics(follow);
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(node.label, 'Unfollow $creator');

    await tester.tap(follow);
    await tester.pumpAndSettle();
    expect(state.isFollowing(creator), isFalse);
    node = tester.getSemantics(follow);
    expect(node.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(node.label, 'Follow $creator');
    semanticsHandle.dispose();
  });

  testWidgets('Community scroll state survives IndexedStack tab switches',
      (tester) async {
    final state = await _pumpHost(
      tester,
      (state) => MainShell(
        listenable: state,
        tabIndex: () => state.tabIndex,
      ),
      tabIndex: 3,
    );

    expect(find.byType(IndexedStack), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byType(CommunityScreen),
      matching: find.byType(Scrollable),
    );
    final scrollState = tester.state<ScrollableState>(scrollable);
    await tester.drag(scrollable, const Offset(0, -320));
    await tester.pumpAndSettle();
    final offset = scrollState.position.pixels;
    expect(offset, greaterThan(0));

    await tester.tap(find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Profile'),
    ));
    await tester.pumpAndSettle();
    expect(state.tabIndex, 4);

    await tester.tap(find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Community'),
    ));
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(scrollable), same(scrollState));
    expect(scrollState.position.pixels, closeTo(offset, 0.01));
    expect(
      find.descendant(
        of: find.byType(CommunityScreen),
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
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screenSize;
  tester.view.padding = _safeAreaInsets;
  tester.view.viewPadding = _safeAreaInsets;
  addTearDown(tester.view.reset);

  final state = AppState();
  addTearDown(state.dispose);
  if (load) await state.load();
  state.tabIndex = tabIndex;
  for (final base in state.bases.take(favourites)) {
    state.toggleFavorite(base.id);
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
