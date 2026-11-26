import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/chips.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/models/filters.dart';
import 'package:fortiq/features/explore/explore_screen.dart';

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

  testWidgets('Explore sort control announces its value and changes sorting',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState();
    addTearDown(state.dispose);
    await state.load();

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const ExploreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sort = find.byKey(const Key('explore-sort'));
    expect(tester.getSemantics(sort).label, 'Sort bases, Top rated');
    expect(tester.getSize(sort).height, greaterThanOrEqualTo(44));
    await tester.tap(sort);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Most copied').last);
    await tester.pumpAndSettle();
    expect(state.sort, BaseSort.mostCopied);
    semantics.dispose();
  });

  testWidgets('Explore filters announce the active count and open the sheet',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState();
    addTearDown(state.dispose);
    await state.load();
    state.filters.categories.add('War');

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const ExploreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filters = find.byKey(const Key('explore-filters'));
    expect(tester.getSemantics(filters).label, 'Filters, 1 active filter');
    expect(tester.getSize(filters).height, greaterThanOrEqualTo(44));
    await tester.tap(filters);
    await tester.pumpAndSettle();
    expect(find.text('Show Results'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Explore quick chips accept taps above and below their artwork',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState();
    addTearDown(state.dispose);
    await state.load();
    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const ExploreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final all = find.widgetWithText(PillChip, 'All');
    final home = find.widgetWithText(PillChip, 'Home Village');
    final allVisual = find.descendant(
      of: all,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxHeight == 34,
      ),
    );
    final homeVisual = find.descendant(
      of: home,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxHeight == 34,
      ),
    );
    final allRect = tester.getRect(allVisual);
    final homeRect = tester.getRect(homeVisual);
    expect(allRect.height, 34, reason: 'The approved artwork is unchanged');
    expect(homeRect.height, 34, reason: 'The approved artwork is unchanged');

    await tester.tapAt(Offset(allRect.center.dx, allRect.top - 3));
    await tester.pumpAndSettle();
    expect(state.filters.village, isNull);

    await tester.tapAt(Offset(homeRect.center.dx, homeRect.bottom + 3));
    await tester.pumpAndSettle();
    expect(state.filters.village, Village.home);
  });
}
