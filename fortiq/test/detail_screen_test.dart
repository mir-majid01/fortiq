import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/base_preview_image.dart';
import 'package:fortiq/core/widgets/buttons.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';
import 'package:fortiq/features/base_detail/base_detail_screen.dart';
import 'package:fortiq/features/base_detail/expanded_base_preview.dart';

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

  testWidgets('detail actions are accessible without a Follow control',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);
    await state.load();
    final base = state.baseById('obsidian-ring')!;

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: BaseDetailScreen(base: base),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copy = find.byKey(const Key('detail-copy'));
    expect(copy, findsOneWidget);
    expect(tester.getSize(copy).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(copy).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(copy).hasFlag(SemanticsFlag.isButton),
      isTrue,
    );
    expect(tester.getSemantics(copy).label, 'Copy base link');

    expect(find.byKey(const Key('detail-follow')), findsNothing);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
    expect(find.text(base.creator.name), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
      'real catalogue details show source attribution without an empty style chip',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);
    await state.load();
    const base = BaseLayout(
      id: 'attributed-detail',
      name: 'Attributed Detail',
      village: Village.home,
      hallLevel: 17,
      categories: ['War'],
      layoutStyle: '',
      previewSeed: 3,
      creator: Creator(name: ''),
      isSample: false,
      gameLink:
          'https://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA',
      sourceAttribution: 'Fixture Source',
    );

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const BaseDetailScreen(base: base),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Source: Fixture Source'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is Text && widget.data == ''),
      findsNothing,
    );
  });

  testWidgets('real catalogue entries explain missing stats and provenance',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);
    await state.load();
    final sample = state.baseById('obsidian-ring')!;
    final base = BaseLayout(
      id: 'community-layout',
      name: 'Community Layout',
      village: sample.village,
      hallLevel: sample.hallLevel,
      categories: sample.categories,
      layoutStyle: sample.layoutStyle,
      previewSeed: sample.previewSeed,
      creator: const Creator(name: 'Community Builder'),
      isSample: false,
      gameLink: 'https://link.clashofclans.com/en?id=community-layout',
      imageUrl: 'https://example.test/community-layout.png',
    );

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: BaseDetailScreen(base: base),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('|'), findsNothing);
    expect(find.textContaining('Community layout'), findsOneWidget);
    expect(find.textContaining('not independently verified'), findsOneWidget);
    expect(find.byType(BasePreviewImage), findsOneWidget);

    await tester.tap(find.byWidgetPredicate(
      (widget) => widget is OverlayIconButton && widget.label == 'Zoom layout',
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ExpandedBasePreview), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ExpandedBasePreview),
        matching: find.byType(BasePreviewImage),
      ),
      findsOneWidget,
    );
  });

  testWidgets('expanded preview has an accessible zoom-in alternative',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFortiqTheme(),
        home: const ExpandedBasePreview(seed: 3, title: 'Obsidian Ring'),
      ),
    );
    await tester.pumpAndSettle();

    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.transformationController!.value, Matrix4.identity());

    final zoomIn = find.byKey(const Key('preview-zoom-in'));
    expect(zoomIn, findsOneWidget);
    expect(tester.getSemantics(zoomIn).label, 'Zoom in');
    await tester.tap(zoomIn);
    await tester.pumpAndSettle();

    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );

    await tester.tap(find.byKey(const Key('preview-reset')));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value, Matrix4.identity());
    semantics.dispose();
  });
}
