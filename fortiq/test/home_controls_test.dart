import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/tabs.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/chips.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';
import 'package:fortiq/features/home/home_screen.dart';

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

  testWidgets('Home header keeps notifications and has no profile affordance',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);
    await state.load();

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final notifications = find.byKey(const Key('home-notifications'));
    expect(tester.getSemantics(notifications).label,
        'Notifications, all caught up');
    expect(tester.getSize(notifications).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(notifications).height, greaterThanOrEqualTo(44));
    await tester.tap(notifications);
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up"), findsOneWidget);
    Navigator.of(tester.element(find.text("You're all caught up"))).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-profile')), findsNothing);
    expect(find.semantics.byLabel('Open profile'), findsNothing);
    expect(state.tabIndex, AppTab.home);
    semantics.dispose();
  });

  testWidgets('Trending position follows the horizontal list scroll',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);
    await state.load();

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final position = find.byKey(const Key('trending-position'));
    expect(tester.getSemantics(position).label, 'Page 1 of 3');
    final list = find.ancestor(
      of: find.text('Hollow Crown'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
    await tester.drag(list, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(position).label, 'Page 3 of 3');
    semantics.dispose();
  });

  testWidgets('Home village tabs announce selection and switch villages',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final state = await _pumpHome(tester);
    final home = find.byKey(const Key('home-village-home'));
    final builder = find.byKey(const Key('home-village-builder'));

    expect(tester.getSemantics(home).label, 'Home Village');
    expect(tester.getSemantics(home).role, SemanticsRole.tab);
    expect(tester.getSemantics(home).hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(tester.getSemantics(builder).label, 'Builder Base');
    expect(tester.getSemantics(builder).role, SemanticsRole.tab);
    expect(
      tester.getSemantics(builder).hasFlag(SemanticsFlag.isSelected),
      isFalse,
    );

    final visual = find.descendant(
      of: builder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxHeight == 38,
      ),
    );
    final visualRect = tester.getRect(visual);
    expect(visualRect.height, 38, reason: 'The approved artwork is unchanged');
    await tester.tapAt(Offset(visualRect.center.dx, visualRect.top - 3));
    await tester.pumpAndSettle();

    expect(state.village, Village.builder);
    expect(
      tester.getSemantics(builder).hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
    expect(
        tester.getSemantics(home).hasFlag(SemanticsFlag.isSelected), isFalse);
    semantics.dispose();
  });

  testWidgets('Home category pills announce their action and open Explore',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final state = await _pumpHome(tester);
    final war = find.byKey(const Key('home-category-War'));

    expect(tester.getSemantics(war).label, 'Explore War bases');
    expect(tester.getSemantics(war).hasFlag(SemanticsFlag.isButton), isTrue);
    expect(tester.getSize(war).height, greaterThanOrEqualTo(44));
    await tester.tap(war);
    await tester.pumpAndSettle();

    expect(state.tabIndex, AppTab.explore);
    expect(state.filters.categories, {'War'});
    semantics.dispose();
  });

  testWidgets('Section View all actions keep a 44px target and open Explore',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final state = await _pumpHome(tester);
    final action = find.bySemanticsLabel('View all Categories');

    expect(action, findsOneWidget);
    expect(tester.getSemantics(action).hasFlag(SemanticsFlag.isButton), isTrue);
    final label = find.descendant(of: action, matching: find.text('View all'));
    expect(tester.getSize(label).height, 13);
    await Scrollable.ensureVisible(tester.element(action), alignment: 0.5);
    await tester.pumpAndSettle();
    final labelRect = tester.getRect(label);
    await tester.tapAt(Offset(labelRect.center.dx, labelRect.top - 12));
    await tester.pumpAndSettle();

    expect(state.tabIndex, AppTab.explore);
    semantics.dispose();
  });

  testWidgets('Home hall chips accept taps above and below their artwork',
      (tester) async {
    final state = await _pumpHome(tester);
    final th18 = find.widgetWithText(HallChip, 'TH 18');
    final th17 = find.widgetWithText(HallChip, 'TH 17');
    final visual18 = find.descendant(
      of: th18,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxHeight == 38,
      ),
    );
    final visual17 = find.descendant(
      of: th17,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxHeight == 38,
      ),
    );
    final rect18 = tester.getRect(visual18);
    final rect17 = tester.getRect(visual17);
    expect(rect18.height, 38, reason: 'The approved artwork is unchanged');
    expect(rect17.height, 38, reason: 'The approved artwork is unchanged');

    await tester.tapAt(Offset(rect18.center.dx, rect18.top - 3));
    await tester.pumpAndSettle();
    expect(state.hallLevel, 18);

    await tester.tapAt(Offset(rect17.center.dx, rect17.bottom + 2.9));
    await tester.pumpAndSettle();
    expect(state.hallLevel, 17);
  });

  testWidgets('Recent base game actions are named and reachable by touch',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final state = await _pumpHome(tester);
    final base = state.recent.first;
    final action = find.byKey(ValueKey('home-recent-open-${base.id}'));
    await tester.scrollUntilVisible(
      action,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.getSemantics(action).label, 'Open ${base.name} in game');
    expect(tester.getSemantics(action).hasFlag(SemanticsFlag.isButton), isTrue);
    expect(tester.getSize(action), const Size(44, 44));
    final visual = find.descendant(
      of: action,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 40 && widget.height == 40,
      ),
    );
    expect(tester.getSize(visual), const Size(40, 40));
    await Scrollable.ensureVisible(tester.element(action), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.textContaining('placeholder base from the design sample'),
        findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    final visualRect = tester.getRect(visual);
    await tester.tapAt(Offset(visualRect.right + 1.9, visualRect.center.dy));
    await tester.pumpAndSettle();

    expect(find.textContaining('placeholder base from the design sample'),
        findsOneWidget);
    semantics.dispose();
  });
}

Future<AppState> _pumpHome(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final state = AppState(repository: SampleBaseRepository());
  addTearDown(state.dispose);
  await state.load();
  await tester.pumpWidget(
    StateScope(
      state: state,
      child: MaterialApp(
        theme: buildFortiqTheme(),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}
