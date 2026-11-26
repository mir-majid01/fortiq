import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/core/widgets/chips.dart';

Future<void> _pumpControl(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

Finder _descendant(Finder control, Type type) {
  return find.descendant(of: control, matching: find.byType(type)).first;
}

SemanticsNode _controlSemantics(WidgetTester tester, Finder control) {
  final semantics = find.descendant(
    of: control,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.container && widget.excludeSemantics,
    ),
  );
  expect(semantics, findsOneWidget);
  return tester.getSemantics(semantics);
}

Future<void> _tapAbove(WidgetTester tester, Finder visual) async {
  await tester.tapAt(tester.getRect(visual).topCenter + const Offset(0, -2));
  await tester.pumpAndSettle();
}

Future<void> _tapBelow(WidgetTester tester, Finder visual) async {
  await tester.tapAt(tester.getRect(visual).bottomCenter + const Offset(0, 2));
  await tester.pumpAndSettle();
}

void _expectIsolated(SemanticsNode node) {
  expect(node.childrenCount, 0);
}

void _expectChipSemantics(
  SemanticsNode node, {
  required String label,
  required bool selected,
  required bool enabled,
}) {
  final flags = node.getSemanticsData().flagsCollection;
  expect(node.label, label);
  expect(flags.isButton, isTrue);
  expect(flags.isSelected.toBoolOrNull(), selected);
  expect(flags.isEnabled.toBoolOrNull(), enabled);
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), enabled);
  _expectIsolated(node);
}

void _expectTabSemantics(
  SemanticsNode node, {
  required String label,
  required bool selected,
}) {
  final data = node.getSemanticsData();
  final flags = data.flagsCollection;
  expect(data.role, SemanticsRole.tab);
  expect(node.label, label);
  expect(flags.isSelected.toBoolOrNull(), selected);
  expect(flags.isEnabled.toBoolOrNull(), isTrue);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
  _expectIsolated(node);
}

void _expectSwitchSemantics(
  SemanticsNode node, {
  required bool value,
  required bool enabled,
}) {
  final flags = node.getSemanticsData().flagsCollection;
  expect(flags.isToggled.toBoolOrNull(), value);
  expect(flags.isEnabled.toBoolOrNull(), enabled);
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), enabled);
  _expectIsolated(node);
}

void main() {
  testWidgets('PillChip announces isolated selection and keeps its 34px visual',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = false;
    var taps = 0;
    await _pumpControl(
      tester,
      StatefulBuilder(
        builder: (context, setState) => PillChip(
          label: 'War',
          selected: selected,
          onTap: () {
            taps++;
            setState(() => selected = !selected);
          },
        ),
      ),
    );

    final control = find.byType(PillChip);
    final visual = _descendant(control, Material);
    expect(tester.getSize(visual).height, 34);
    _expectChipSemantics(
      _controlSemantics(tester, control),
      label: 'War',
      selected: false,
      enabled: true,
    );

    await _tapAbove(tester, visual);
    expect(taps, 1);
    expect(selected, isTrue);
    expect(tester.getSize(visual).height, 34);
    _expectChipSemantics(
      _controlSemantics(tester, control),
      label: 'War',
      selected: true,
      enabled: true,
    );

    await _tapBelow(tester, visual);
    expect(taps, 2);
    expect(selected, isFalse);
    _expectChipSemantics(
      _controlSemantics(tester, control),
      label: 'War',
      selected: false,
      enabled: true,
    );
    semantics.dispose();
  });

  testWidgets('PillChip exposes disabled button semantics without a tap action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpControl(
      tester,
      const PillChip(label: 'War', selected: false),
    );

    _expectChipSemantics(
      _controlSemantics(tester, find.byType(PillChip)),
      label: 'War',
      selected: false,
      enabled: false,
    );
    semantics.dispose();
  });

  testWidgets('HallChip announces isolated selection and keeps its 38px visual',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = false;
    var taps = 0;
    await _pumpControl(
      tester,
      StatefulBuilder(
        builder: (context, setState) => HallChip(
          label: 'TH 17',
          selected: selected,
          onTap: () {
            taps++;
            setState(() => selected = !selected);
          },
        ),
      ),
    );

    final control = find.byType(HallChip);
    final visual = _descendant(control, Material);
    expect(tester.getSize(visual).height, 38);
    _expectChipSemantics(
      _controlSemantics(tester, control),
      label: 'TH 17',
      selected: false,
      enabled: true,
    );

    await _tapAbove(tester, visual);
    expect(taps, 1);
    expect(selected, isTrue);
    expect(tester.getSize(visual).height, 38);
    _expectChipSemantics(
      _controlSemantics(tester, control),
      label: 'TH 17',
      selected: true,
      enabled: true,
    );

    await _tapBelow(tester, visual);
    expect(taps, 2);
    expect(selected, isFalse);
    semantics.dispose();
  });

  testWidgets('sheet HallChip keeps its 56x36 visual with a 44px-high target',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await _pumpControl(
      tester,
      HallChip(
        label: 'TH 17',
        width: 56,
        height: 36,
        selected: true,
        onTap: () => taps++,
      ),
    );

    final control = find.byType(HallChip);
    final visual = _descendant(control, Material);
    expect(tester.getSize(visual), const Size(56, 36));
    _expectChipSemantics(
      _controlSemantics(tester, control),
      label: 'TH 17',
      selected: true,
      enabled: true,
    );

    await _tapAbove(tester, visual);
    expect(taps, 1);
    await _tapBelow(tester, visual);
    expect(taps, 2);
    expect(tester.getSize(visual), const Size(56, 36));
    semantics.dispose();
  });

  testWidgets('HallChip exposes disabled button semantics without a tap action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpControl(
      tester,
      const HallChip(label: 'TH 17', selected: true),
    );

    _expectChipSemantics(
      _controlSemantics(tester, find.byType(HallChip)),
      label: 'TH 17',
      selected: true,
      enabled: false,
    );
    semantics.dispose();
  });

  testWidgets('SegmentedToggle exposes isolated tabs and 44px-high targets',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = 0;
    final selections = <int>[];
    await _pumpControl(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SegmentedToggle(
          options: const ['Home Village', 'Builder Base'],
          selected: selected,
          onSelect: (index) {
            selections.add(index);
            setState(() => selected = index);
          },
        ),
      ),
    );

    final first = find.byKey(const ValueKey('segmented-option-0'));
    final second = find.byKey(const ValueKey('segmented-option-1'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    _expectTabSemantics(
      tester.getSemantics(first),
      label: 'Home Village',
      selected: true,
    );
    _expectTabSemantics(
      tester.getSemantics(second),
      label: 'Builder Base',
      selected: false,
    );

    final secondVisual = _descendant(second, Container);
    expect(tester.getSize(secondVisual).height, 38);
    await _tapAbove(tester, secondVisual);
    expect(selections, [1]);
    expect(selected, 1);
    _expectTabSemantics(
      tester.getSemantics(first),
      label: 'Home Village',
      selected: false,
    );
    _expectTabSemantics(
      tester.getSemantics(second),
      label: 'Builder Base',
      selected: true,
    );

    await _tapBelow(tester, secondVisual);
    expect(selections, [1, 1]);
    expect(tester.getSize(secondVisual).height, 38);
    semantics.dispose();
  });

  testWidgets(
      'sheet segmented options keep 36px visuals and select on edge taps',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = 1;
    final selections = <int>[];
    await _pumpControl(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SegmentedToggle(
          options: const ['Any', 'Last 24h', 'Last week'],
          selected: selected,
          height: 36,
          onSelect: (index) {
            selections.add(index);
            setState(() => selected = index);
          },
        ),
      ),
    );

    final option = find.byKey(const ValueKey('segmented-option-0'));
    expect(option, findsOneWidget);
    final visual = _descendant(option, Container);
    expect(tester.getSize(visual).height, 36);
    _expectTabSemantics(
      tester.getSemantics(option),
      label: 'Any',
      selected: false,
    );

    await _tapAbove(tester, visual);
    expect(selections, [0]);
    expect(selected, 0);
    await _tapBelow(tester, visual);
    expect(selections, [0, 0]);
    expect(tester.getSize(visual).height, 36);
    _expectTabSemantics(
      tester.getSemantics(option),
      label: 'Any',
      selected: true,
    );
    semantics.dispose();
  });

  testWidgets('ToggleSwitch announces isolated state and keeps its 44x26 track',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var value = false;
    final changes = <bool>[];
    await _pumpControl(
      tester,
      StatefulBuilder(
        builder: (context, setState) => ToggleSwitch(
          value: value,
          onChanged: (next) {
            changes.add(next);
            setState(() => value = next);
          },
        ),
      ),
    );

    final control = find.byType(ToggleSwitch);
    final track = _descendant(control, AnimatedContainer);
    expect(tester.getSize(track), const Size(44, 26));
    _expectSwitchSemantics(
      _controlSemantics(tester, control),
      value: false,
      enabled: true,
    );

    await _tapAbove(tester, track);
    expect(changes, [true]);
    expect(value, isTrue);
    expect(tester.getSize(track), const Size(44, 26));
    _expectSwitchSemantics(
      _controlSemantics(tester, control),
      value: true,
      enabled: true,
    );

    await _tapBelow(tester, track);
    expect(changes, [true, false]);
    expect(value, isFalse);
    expect(tester.getSize(track), const Size(44, 26));
    semantics.dispose();
  });

  testWidgets(
      'disabled ToggleSwitch retains toggled state without a tap action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpControl(
      tester,
      const ToggleSwitch(value: true),
    );

    _expectSwitchSemantics(
      _controlSemantics(tester, find.byType(ToggleSwitch)),
      value: true,
      enabled: false,
    );
    semantics.dispose();
  });
}
