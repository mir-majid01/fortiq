import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/buttons.dart';
import 'package:fortiq/core/widgets/chips.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/models/filters.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';
import 'package:fortiq/features/filters/filters_sheet.dart';

void main() {
  Future<AppState> pumpHost(WidgetTester tester) async {
    final state = AppState(repository: SampleBaseRepository());
    await state.load();
    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const FiltersSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return state;
  }

  testWidgets('sheet shows every filter group and applies selections',
      (tester) async {
    final state = await pumpHost(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsWidgets);
    expect(find.text('VILLAGE'), findsOneWidget);
    expect(find.text('TOWN HALL'), findsOneWidget);
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('LAYOUT STYLE'), findsOneWidget);
    expect(find.text('FRESHNESS'), findsOneWidget);
    expect(find.text('Verified builders only'), findsOneWidget);

    // Select TH 17 + War, toggle verified, apply.
    await tester.tap(find.text('TH 17'));
    await tester.pump();
    await tester.tap(find.text('War'));
    await tester.pump();
    await tester.ensureVisible(find.byType(ToggleSwitch));
    await tester.pump();
    await tester.tap(find.byType(ToggleSwitch));
    await tester.pump();
    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();

    expect(state.filters.hallLevels, {17});
    expect(state.filters.categories, {'War'});
    expect(state.filters.verifiedOnly, isTrue);
    expect(state.filters.activeGroupCount, 3);
  });

  testWidgets('Builder Base uses Builder Hall labels and keeps All villages',
      (tester) async {
    final state = await pumpHost(tester);
    state.applyFilters(ExploreFilters(village: null));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final villageToggle = find.byType(SegmentedToggle).first;
    final toggleRect = tester.getRect(villageToggle);
    await tester.tapAt(Offset(
      toggleRect.left + toggleRect.width * 0.75,
      toggleRect.center.dy,
    ));
    await tester.pump();

    expect(find.text('BUILDER HALL'), findsOneWidget);
    expect(find.text('TOWN HALL'), findsNothing);
    expect(find.text('BH 10'), findsOneWidget);
    expect(state.filters.village, isNull,
        reason: 'sheet edits remain a draft until Show Results');

    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();
    expect(state.filters.village, Village.builder);
  });

  testWidgets('Reset clears the draft, leaving applied state untouched',
      (tester) async {
    final state = await pumpHost(tester);
    state.applyFilters(ExploreFilters()..categories.add('Trophy'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Draft starts from applied state — Trophy selected.
    expect(find.text('Trophy'), findsWidgets);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();

    expect(state.filters.categories, isEmpty);
    expect(state.filters.isDefault, isTrue);
  });

  for (final bottomInset in [0.0, 40.0]) {
    testWidgets('bottom actions clear a $bottomInset bottom inset',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(480, 844);
      tester.view.padding = FakeViewPadding(bottom: bottomInset);
      tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
      addTearDown(tester.view.reset);
      await pumpHost(tester);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final results = find.byType(PrimaryButton);
      final expectedGap = bottomInset == 0 ? 30.0 : bottomInset;
      expect(
        tester.getRect(results).bottom,
        closeTo(844 - expectedGap, 0.01),
        reason: 'The action bar must preserve 30px spacing or the safe inset',
      );
    });
  }

  testWidgets('verified row exposes one named switch and applies one tap',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final state = await pumpHost(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final toggle = find.byType(ToggleSwitch);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: toggle,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.minHeight == 48,
      ),
    );
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, 48);

    final track = find.descendant(
      of: toggle,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.constraints?.maxWidth == 44 &&
            widget.constraints?.maxHeight == 26,
      ),
    );
    expect(track, findsOneWidget);
    expect(tester.getSize(track), const Size(44, 26));

    final switches = find.semantics.byLabel('Verified builders only');
    expect(switches, findsOneWidget);
    final switchNode = switches.evaluate().single;
    expect(
      switchNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    final rowTapNodes = find.semantics.descendant(
      of: switches,
      matching: find.semantics.byAction(SemanticsAction.tap),
      matchRoot: true,
    );
    expect(rowTapNodes, findsOneWidget);
    final usesToggledState = switchNode.hasFlag(SemanticsFlag.hasToggledState);
    expect(
      usesToggledState || switchNode.hasFlag(SemanticsFlag.hasCheckedState),
      isTrue,
    );
    expect(
      switchNode.hasFlag(
          usesToggledState ? SemanticsFlag.isToggled : SemanticsFlag.isChecked),
      isFalse,
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final toggledNode = switches.evaluate().single;
    expect(
      toggledNode.hasFlag(
          usesToggledState ? SemanticsFlag.isToggled : SemanticsFlag.isChecked),
      isTrue,
    );
    semantics.dispose();
    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();

    expect(state.filters.verifiedOnly, isTrue);
    expect(state.filters.activeGroupCount, 1);
  });

  testWidgets('close control has a named 44px target and dismisses',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final state = await pumpHost(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final close = find.byKey(const Key('filters-close'));
    expect(close, findsOneWidget);
    expect(find.semantics.byLabel('Close filters'), findsOneWidget);
    final closeNode = tester.getSemantics(close);
    expect(closeNode.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(closeNode.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(tester.getSize(close), const Size(44, 44));

    final artwork = find.descendant(
      of: close,
      matching: find.byType(Material),
    );
    expect(artwork, findsOneWidget);
    expect(tester.getSize(artwork), const Size(36, 36));
    semantics.dispose();

    await tester.tap(find.text('TH 17'));
    await tester.pump();
    final artworkRect = tester.getRect(artwork);
    await tester.tapAt(Offset(artworkRect.center.dx, artworkRect.top - 2));
    await tester.pumpAndSettle();

    expect(find.byType(FiltersSheet), findsNothing);
    expect(state.filters.hallLevels, isEmpty);
  });
}
