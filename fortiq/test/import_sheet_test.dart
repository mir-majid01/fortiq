import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/repositories/base_repository.dart';
import 'package:fortiq/data/repositories/composite_base_repository.dart';
import 'package:fortiq/data/repositories/imported_base_store.dart';
import 'package:fortiq/features/explore/explore_screen.dart';
import 'package:fortiq/features/import/import_base_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _link =
    'https://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA';

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
    for (final entry in fonts.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });

  testWidgets('import sheet validates fields and saves a user-owned base',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final directory = Directory.systemTemp.createTempSync('fortiq-sheet');
    addTearDown(() => directory.deleteSync(recursive: true));
    final repository = CompositeBaseRepository(
      remote: _EmptyBaseRepository(),
      imports: ImportedBaseStore(directory: directory),
    );
    final state = AppState(repository: repository);
    addTearDown(state.dispose);
    await tester.runAsync(state.load);
    final preview = File('${directory.path}/preview.png')
      ..writeAsBytesSync([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x60,
        0x60,
        0x60,
        0x00,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x27,
        0x34,
        0x27,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);
    File? previewForSheet;
    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ImportBaseSheet(previewFile: previewForSheet),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Import base'));
    await tester.pump();
    expect(
        find.text('Choose a preview image you own or have permission to use.'),
        findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    previewForSheet = preview;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import-link')), _link);
    await tester.enterText(find.byKey(const Key('import-name')), 'My Base');
    await tester.enterText(
        find.byKey(const Key('import-attribution')), 'My credit');
    await tester.runAsync(() async {
      await tester.tap(find.text('Import base'));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (state.bases.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ImportBaseSheet), findsNothing);
    expect(state.bases, hasLength(1));
    expect(state.bases.single.name, 'My Base');
    expect(state.bases.single.gameLink, _link);
    expect(state.bases.single.localImagePath, isNotNull);
    expect(state.catalogueUnavailable, isFalse);
  });

  testWidgets('Explore unavailable state opens the import sheet',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final directory =
        Directory.systemTemp.createTempSync('fortiq-explore-import');
    addTearDown(() => directory.deleteSync(recursive: true));
    final state = AppState(
      repository: CompositeBaseRepository(
        remote: _EmptyBaseRepository(),
        imports: ImportedBaseStore(directory: directory),
      ),
    );
    addTearDown(state.dispose);
    await tester.runAsync(state.load);

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const ExploreScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('catalogue-unavailable')), findsOneWidget);
    await tester.tap(find.text('Import a base'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ImportBaseSheet), findsOneWidget);
  });
}

/// Empty remote source used to exercise the unavailable/import path without
/// depending on the packaged production catalogue.
class _EmptyBaseRepository implements BaseRepository {
  @override
  Future<List<BaseLayout>> loadAll() async => const [];

  @override
  bool get isCatalogueUnavailable => true;

  @override
  String? get featuredId => null;

  @override
  List<String> get trendingIds => const [];

  @override
  List<String> get recentIds => const [];
}
