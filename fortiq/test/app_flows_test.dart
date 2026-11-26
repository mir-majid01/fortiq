import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/router.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/tabs.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/app_bottom_nav.dart';
import 'package:fortiq/core/widgets/badges.dart';
import 'package:fortiq/core/widgets/buttons.dart';
import 'package:fortiq/core/storage/local_store.dart';
import 'package:fortiq/core/widgets/chips.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/models/catalogue_rights.dart';
import 'package:fortiq/data/models/filters.dart';
import 'package:fortiq/data/repositories/base_repository.dart';
import 'package:fortiq/data/sources/clash_bases_source.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';
import 'package:fortiq/features/base_detail/base_detail_screen.dart';
import 'package:fortiq/features/base_detail/expanded_base_preview.dart';
import 'package:fortiq/features/collections/collections_screen.dart';
import 'package:fortiq/features/explore/explore_screen.dart';
import 'package:fortiq/features/explore/widgets/explore_base_card.dart';
import 'package:fortiq/features/filters/filters_sheet.dart';
import 'package:fortiq/features/home/home_screen.dart';
import 'package:fortiq/features/home/widgets/featured_base_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
const _launchChannel = MethodChannel('plugins.flutter.io/url_launcher');
const _shareUnavailable = 'dev.fluttercommunity.plus/share/unavailable';
const _catalogueError = 'The base catalogue could not be loaded.';
const _clearedDetailLink =
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_launchChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_launchChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('MainShell visits only the three production destinations',
      (tester) async {
    final state = await _pumpLoadedShell(tester);
    const destinations = <({int index, String label, Type screen})>[
      (index: AppTab.home, label: 'Home', screen: HomeScreen),
      (index: AppTab.explore, label: 'Explore', screen: ExploreScreen),
      (
        index: AppTab.collections,
        label: 'Collections',
        screen: CollectionsScreen
      ),
    ];

    expect(find.byType(IndexedStack), findsOneWidget);
    expect(_tabLabel('Community'), findsNothing);
    expect(_tabLabel('Profile'), findsNothing);
    for (final destination in destinations) {
      if (destination.index != AppTab.home) {
        await _tapTab(tester, destination.label);
      }

      expect(state.tabIndex, destination.index);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        destination.index,
      );
      expect(find.byType(destination.screen), findsOneWidget);
      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        destination.index,
      );
      expect(_tabLabel(destination.label), findsOneWidget);
    }

    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(
      stack.children.map((child) => child.runtimeType),
      [HomeScreen, ExploreScreen, CollectionsScreen],
    );

    state.tabIndex = 4;
    await tester.pumpAndSettle();
    expect(state.tabIndex, AppTab.collections);
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      AppTab.collections,
    );
    expect(
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
      AppTab.collections,
    );
  });

  testWidgets('IndexedStack preserves Home/Explore scroll and search input',
      (tester) async {
    final state = await _pumpLoadedShell(tester);
    final homeScroll = _verticalScrollIn(find.byType(HomeScreen));
    final homeState = tester.state<ScrollableState>(homeScroll);
    await tester.drag(homeScroll, const Offset(0, -520));
    await tester.pumpAndSettle();
    final homeOffset = homeState.position.pixels;
    expect(homeOffset, greaterThan(0));

    await _tapTab(tester, 'Explore');
    final gridScroll = _verticalScrollIn(find.byType(ExploreScreen));
    final gridState = tester.state<ScrollableState>(gridScroll);
    await tester.drag(gridScroll, const Offset(0, -520));
    await tester.pumpAndSettle();
    final gridOffset = gridState.position.pixels;
    expect(gridOffset, greaterThan(0));

    await _tapTab(tester, 'Home');
    expect(tester.state<ScrollableState>(homeScroll), same(homeState));
    expect(homeState.position.pixels, closeTo(homeOffset, 0.01));

    await _tapTab(tester, 'Explore');
    expect(tester.state<ScrollableState>(gridScroll), same(gridState));
    expect(gridState.position.pixels, closeTo(gridOffset, 0.01));

    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).controller,
        same(state.searchController));
    await tester.enterText(field, 'obs');
    await tester.pump();
    expect(state.query, 'obs');

    await _tapTab(tester, 'Collections');
    await _tapTab(tester, 'Explore');
    expect(state.query, 'obs');
    expect(tester.widget<TextField>(field).controller,
        same(state.searchController));
    expect(tester.widget<TextField>(field).controller!.text, 'obs');
  });

  testWidgets(
      'Home category handoff scopes Explore and preserves shared search',
      (tester) async {
    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);
    await state.load();
    state.selectHallLevel(17);
    state.setSearch('ring');
    state.filters
      ..village = Village.builder
      ..categories.add('Trophy')
      ..styles.add('Box');
    state.notifyFilterChanged();
    await _pumpShell(tester, state);

    final war = find.byKey(const Key('home-category-War'));
    await tester.scrollUntilVisible(
      war,
      320,
      scrollable: _verticalScrollIn(find.byType(HomeScreen)),
    );
    await tester.tap(war);
    await tester.pumpAndSettle();

    expect(state.tabIndex, AppTab.explore);
    expect(find.byType(ExploreScreen), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller, same(state.searchController));
    expect(field.controller!.text, 'ring');
    expect(state.filters.village, Village.home);
    expect(state.filters.hallLevels, {17});
    expect(state.filters.categories, {'War'});
    expect(state.filters.styles, isEmpty);
    expect(state.exploreResults, isNotEmpty);
    expect(
      state.exploreResults.every(
        (base) =>
            base.village == Village.home &&
            base.hallLevel == 17 &&
            base.categories.contains('War'),
      ),
      isTrue,
    );
    expect(_exploreCard('obsidian-ring'), findsOneWidget);
  });

  testWidgets(
      'Explore quick chips, result counts, badge and sorting stay in sync',
      (tester) async {
    final state = await _pumpLoadedShell(tester, tabIndex: AppTab.explore);
    final filtersButton = find.byKey(const Key('explore-filters'));
    expect(find.text('86 bases'), findsOneWidget);

    await _tapQuickChip(tester, 'All');
    expect(state.filters.village, isNull);
    expect(find.text('104 bases'), findsOneWidget);
    expect(tester.widget<PillChip>(_quickChip('All')).selected, isTrue);

    await _tapQuickChip(tester, 'Home Village');
    expect(state.filters.village, Village.home);
    expect(find.text('86 bases'), findsOneWidget);

    await _tapQuickChip(tester, 'Builder Base');
    expect(state.filters.village, Village.builder);
    expect(find.text('18 bases'), findsOneWidget);
    expect(
      state.exploreResults.every((base) => base.village == Village.builder),
      isTrue,
    );
    expect(
      find.descendant(of: filtersButton, matching: find.text('1')),
      findsOneWidget,
    );

    await _tapQuickChip(tester, 'War');
    expect(state.filters.categories, {'War'});
    expect(
      state.exploreResults.every(
        (base) =>
            base.village == Village.builder && base.categories.contains('War'),
      ),
      isTrue,
    );
    expect(
      find.descendant(of: filtersButton, matching: find.text('2')),
      findsOneWidget,
    );

    await _tapQuickChip(tester, 'War');
    expect(state.filters.categories, isEmpty);
    expect(
      find.descendant(of: filtersButton, matching: find.text('1')),
      findsOneWidget,
    );

    await _tapQuickChip(tester, 'Home Village');
    expect(state.filters.activeGroupCount, 0);
    expect(find.text('86 bases'), findsOneWidget);
    expect(
      find.descendant(of: filtersButton, matching: find.text('1')),
      findsNothing,
    );

    for (final sort in [
      BaseSort.mostCopied,
      BaseSort.newest,
      BaseSort.topRated
    ]) {
      await tester.tap(find.byKey(const Key('explore-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sort.label).last);
      await tester.pumpAndSettle();

      expect(state.sort, sort);
      expect(find.text('86 bases'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('explore-sort')),
          matching: find.text(sort.label),
        ),
        findsOneWidget,
      );
      final firstCard = tester.widget<ExploreBaseCard>(
        find.byType(ExploreBaseCard).first,
      );
      expect(firstCard.base.id, state.exploreResults.first.id);
    }
  });

  testWidgets(
      'Explore filter sheet applies a draft and reset updates the badge',
      (tester) async {
    final state = await _pumpLoadedShell(tester, tabIndex: AppTab.explore);
    final filtersButton = find.byKey(const Key('explore-filters'));
    await tester.tap(filtersButton);
    await tester.pumpAndSettle();
    final sheet = find.byType(FiltersSheet);
    expect(sheet, findsOneWidget);

    final villageToggle = find
        .descendant(
          of: sheet,
          matching: find.byType(SegmentedToggle),
        )
        .first;
    await tester.tapAt(
      tester.getCenter(
        find.descendant(of: villageToggle, matching: find.text('Builder Base')),
      ),
    );
    await tester.pumpAndSettle();
    await _tapSheetChip(tester, 'BH 10', HallChip);
    await _tapSheetChip(tester, 'War', PillChip);
    await _tapSheetChip(tester, 'Ring', PillChip);

    final freshnessToggle = find
        .descendant(
          of: sheet,
          matching: find.byType(SegmentedToggle),
        )
        .last;
    await tester.ensureVisible(freshnessToggle);
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(
        find.descendant(of: freshnessToggle, matching: find.text('7 days')),
      ),
    );
    await tester.pumpAndSettle();
    final verified = find.descendant(
      of: sheet,
      matching: find.byType(ToggleSwitch),
    );
    await tester.ensureVisible(verified);
    await tester.pumpAndSettle();
    await tester.tap(verified);
    await tester.pumpAndSettle();

    expect(state.filters.isDefault, isTrue,
        reason: 'sheet edits must remain a draft until Show Results');
    expect(
      find.descendant(of: filtersButton, matching: find.text('6')),
      findsNothing,
    );
    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(state.filters.village, Village.builder);
    expect(state.filters.hallLevels, {10});
    expect(state.filters.categories, {'War'});
    expect(state.filters.styles, {'Ring'});
    expect(state.filters.freshness, Freshness.sevenDays);
    expect(state.filters.verifiedOnly, isTrue);
    expect(state.filters.activeGroupCount, 6);
    expect(
      find.descendant(of: filtersButton, matching: find.text('6')),
      findsOneWidget,
    );

    await tester.tap(filtersButton);
    await tester.pumpAndSettle();
    expect(
      tester.widget<HallChip>(_sheetChip('BH 10', HallChip)).selected,
      isTrue,
    );
    expect(
      tester.widget<PillChip>(_sheetChip('War', PillChip)).selected,
      isTrue,
    );
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(state.filters.activeGroupCount, 6,
        reason: 'Reset edits the draft without mutating applied state');
    final hallChips = find.descendant(
      of: sheet,
      matching: find.byType(HallChip),
    );
    expect(hallChips, findsWidgets);
    expect(
      hallChips.evaluate().map(
            (element) => (element.widget as HallChip).selected,
          ),
      everyElement(isFalse),
    );
    expect(
      tester.widget<PillChip>(_sheetChip('War', PillChip)).selected,
      isFalse,
    );

    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();
    expect(state.filters.isDefault, isTrue);
    expect(find.text('86 bases'), findsOneWidget);
    expect(
      find.descendant(of: filtersButton, matching: find.text('6')),
      findsNothing,
    );
  });

  testWidgets('saving in Explore reaches Collections and Detail can unsave it',
      (tester) async {
    final state = await _pumpLoadedShell(tester, tabIndex: AppTab.explore);
    const id = 'obsidian-ring';
    final card = _exploreCard(id);
    final heart = find.descendant(of: card, matching: find.byType(HeartButton));
    expect(tester.widget<HeartButton>(heart).favorited, isFalse);

    await tester.tap(heart);
    await tester.pumpAndSettle();
    expect(state.isFavorite(id), isTrue);
    expect(tester.widget<HeartButton>(heart).favorited, isTrue);
    expect(await LocalStore().loadFavouriteIds(), [id]);

    await _tapTab(tester, 'Collections');
    final savedName = find.descendant(
      of: find.byType(CollectionsScreen),
      matching: find.text('Obsidian Ring'),
    );
    expect(savedName, findsOneWidget);
    await tester.tap(savedName);
    await tester.pumpAndSettle();

    final detail = find.byType(BaseDetailScreen);
    expect(tester.widget<BaseDetailScreen>(detail).base.id, id);
    final detailHeart = find.descendant(
      of: detail,
      matching: find.byType(HeartButton),
    );
    expect(tester.widget<HeartButton>(detailHeart).favorited, isTrue);
    await tester.tap(detailHeart);
    await tester.pumpAndSettle();
    expect(state.isFavorite(id), isFalse);
    expect(tester.widget<HeartButton>(detailHeart).favorited, isFalse);
    expect(await LocalStore().loadFavouriteIds(), isEmpty);

    await tester.tap(_detailAction('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionsScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CollectionsScreen),
        matching: find.text('Obsidian Ring'),
      ),
      findsNothing,
    );
    expect(
      find.text('Tap the heart on any base to save it here for later.'),
      findsOneWidget,
    );

    await _tapTab(tester, 'Explore');
    expect(tester.widget<HeartButton>(heart).favorited, isFalse);
  });

  testWidgets('saved favourites restore into a new AppState', (tester) async {
    await _pumpLoadedShell(tester, tabIndex: AppTab.explore);
    await tester.tap(
      find.descendant(
        of: _exploreCard('obsidian-ring'),
        matching: find.byType(HeartButton),
      ),
    );
    await tester.pumpAndSettle();

    final restored = AppState(repository: SampleBaseRepository());
    addTearDown(restored.dispose);
    await tester.runAsync(restored.loadPersistedState);
    await tester.runAsync(restored.load);
    restored.tabIndex = AppTab.collections;
    await _pumpShell(tester, restored);

    expect(restored.isFavorite('obsidian-ring'), isTrue);
    expect(find.text('Obsidian Ring'), findsOneWidget);
  });

  testWidgets('failed favourite writes preserve state and show an error',
      (tester) async {
    final state = AppState(
      repository: SampleBaseRepository(),
      store: _FailingFavouriteStore(),
    );
    addTearDown(state.dispose);
    await state.load();
    state.tabIndex = AppTab.explore;
    await _pumpShell(tester, state);
    final base = state.bases.first;

    await tester.tap(find.byKey(Key('explore-favorite-${base.id}')));
    await tester.pumpAndSettle();

    expect(state.isFavorite(base.id), isFalse);
    expect(
      find.text('Could not update saved bases. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'sample Detail Open in Game is honest and Back returns to Explore',
      (tester) async {
    var launchCalls = 0;
    var clipboardCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_launchChannel, (call) async {
      launchCalls++;
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCalls++;
      return null;
    });
    final state = await _pumpLoadedShell(tester, tabIndex: AppTab.explore);
    await tester.tap(_exploreCard('obsidian-ring'));
    await tester.pumpAndSettle();

    final detail = find.byType(BaseDetailScreen);
    expect(tester.widget<BaseDetailScreen>(detail).base.isSample, isTrue);
    await tester.tap(
      find.descendant(of: detail, matching: find.text('Open in Game')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('placeholder base from the design sample'),
      findsOneWidget,
    );
    expect(find.text('Got it'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(launchCalls, 0);
    expect(clipboardCalls, 0);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('placeholder base from the design sample'),
      findsNothing,
    );
    expect(detail, findsOneWidget);

    await tester.tap(_detailAction('Back'));
    await tester.pumpAndSettle();
    expect(detail, findsNothing);
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(state.tabIndex, AppTab.explore);
  });

  testWidgets('real Detail copy shows one clipboard SnackBar in MainShell',
      (tester) async {
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    final base = await _openFirstRealDetail(tester);
    await tester.tap(find.byKey(const Key('detail-copy')));
    await tester.pumpAndSettle();

    expect(clipboardText, base.gameLink);
    expect(
      find.text('Base link copied to clipboard'),
      findsOneWidget,
      reason: 'the Detail action must not broadcast duplicate SnackBars to '
          'the tab Scaffolds retained by MainShell',
    );

    await tester.tap(_detailAction('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(BaseDetailScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('real Detail unavailable share shows one SnackBar in MainShell',
      (tester) async {
    final shareCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shareCalls.add(call);
      return _shareUnavailable;
    });

    final base = await _openFirstRealDetail(tester);
    await tester.tap(_detailAction('Share base'));
    await tester.pumpAndSettle();

    expect(shareCalls, hasLength(1));
    expect(shareCalls.single.method, 'share');
    final arguments =
        Map<String, dynamic>.from(shareCalls.single.arguments as Map);
    expect(arguments['text'], contains(base.name));
    expect(arguments['text'], contains(base.gameLink!));
    expect(
      find.text('Sharing is unavailable on this device.'),
      findsOneWidget,
      reason: 'the Detail action must not broadcast duplicate SnackBars to '
          'the tab Scaffolds retained by MainShell',
    );

    await tester.tap(_detailAction('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(BaseDetailScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('expanded preview supports double-tap, semantic zoom and back',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpLoadedShell(tester, tabIndex: AppTab.explore);
      await tester.tap(_exploreCard('obsidian-ring'));
      await tester.pumpAndSettle();
      await tester.tap(_detailAction('Zoom layout'));
      await tester.pumpAndSettle();

      final expanded = find.byType(ExpandedBasePreview);
      final viewer = tester.widget<InteractiveViewer>(
        find.descendant(of: expanded, matching: find.byType(InteractiveViewer)),
      );
      final preview = find.descendant(
        of: expanded,
        matching: find.byType(AspectRatio),
      );
      expect(viewer.transformationController!.value, Matrix4.identity());
      expect(find.semantics.byLabel('Zoom in'), findsOneWidget);
      expect(find.semantics.byLabel('Reset zoom'), findsOneWidget);
      expect(find.semantics.byLabel('Close expanded preview'), findsOneWidget);

      await _doubleTap(tester, preview);
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(2.5, 0.001),
      );

      await tester.tap(find.byKey(const Key('preview-zoom-in')));
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(3.75, 0.001),
      );

      await tester.tap(find.byKey(const Key('preview-reset')));
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value, Matrix4.identity());

      await _doubleTap(tester, preview);
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(2.5, 0.001),
      );
      await _doubleTap(tester, preview);
      expect(viewer.transformationController!.value, Matrix4.identity());

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(expanded, findsNothing);
      expect(find.byType(BaseDetailScreen), findsOneWidget);

      await tester.tap(_detailAction('Zoom layout'));
      await tester.pumpAndSettle();
      await tester.tap(_detailAction('Close expanded preview'));
      await tester.pumpAndSettle();
      expect(expanded, findsNothing);
      expect(find.byType(BaseDetailScreen), findsOneWidget);

      await tester.tap(_detailAction('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(BaseDetailScreen), findsNothing);
      expect(find.byType(ExploreScreen), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('MainShell catalogue failure can be retried into real results',
      (tester) async {
    final repository = _FailingThenSampleRepository();
    final state = AppState(repository: repository);
    addTearDown(state.dispose);
    await _pumpShell(tester, state);

    final loading = state.load();
    await tester.pumpAndSettle();
    await loading;
    expect(state.isLoaded, isFalse);
    expect(state.loadError, _catalogueError);
    expect(find.text(_catalogueError), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.loadCalls, 2);
    expect(state.isLoaded, isTrue);
    expect(state.loadError, isNull);
    expect(find.text(_catalogueError), findsNothing);
    expect(find.byType(FeaturedBaseCard), findsOneWidget);

    await _tapTab(tester, 'Explore');
    expect(find.text('86 bases'), findsOneWidget);
    expect(_exploreCard('obsidian-ring'), findsOneWidget);
  });

  testWidgets('disposing MainShell during a catalogue load is silent',
      (tester) async {
    final sample = await SampleBaseRepository().loadAll();
    final response = Completer<List<BaseLayout>>();
    final state =
        AppState(repository: _PendingSampleRepository(response.future));
    var disposed = false;
    addTearDown(() {
      if (!disposed) state.dispose();
    });
    var notifications = 0;
    state.addListener(() => notifications++);
    await _pumpShell(tester, state);

    final loading = state.load();
    await tester.pump();
    expect(state.isLoading, isTrue);
    expect(notifications, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    disposed = true;
    response.complete(sample);
    await expectLater(loading, completes);
    await tester.pump();

    expect(notifications, 1,
        reason: 'a late repository response must not notify disposed state');
    expect(state.isLoaded, isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<AppState> _pumpLoadedShell(
  WidgetTester tester, {
  int tabIndex = AppTab.home,
  BaseRepository? repository,
}) async {
  final state = AppState(repository: repository ?? SampleBaseRepository());
  addTearDown(state.dispose);
  await tester.runAsync(() => state.load());
  state.tabIndex = tabIndex;
  await _pumpShell(tester, state);
  return state;
}

Future<void> _pumpShell(WidgetTester tester, AppState state) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    StateScope(
      state: state,
      child: MaterialApp(
        theme: buildFortiqTheme(),
        home: MainShell(
          listenable: state,
          tabIndex: () => state.tabIndex,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<BaseLayout> _openFirstRealDetail(WidgetTester tester) async {
  final base = ClashBasesCatalogRepository.fromJson(
    {
      'id': 'cleared-detail',
      'name': 'Cleared Detail',
      'town_hall': 17,
      'type': 'War',
      'link': _clearedDetailLink,
      'description': 'Rights-cleared detail fixture.',
      'builder': 'Fixture Source',
      'tags': const <String>[],
      'added': '2026-11-20',
      'image': 'https://example.test/cleared-detail.png',
    },
    rightsStatus: CatalogueRightsStatus.cleared,
  );
  await _pumpLoadedShell(
    tester,
    repository: _ClearedDetailRepository(base),
  );
  expect(base.gameLink, isNotNull);
  await tester.tap(find.byType(FeaturedBaseCard));
  await tester.pumpAndSettle();
  final detail = find.byType(BaseDetailScreen);
  expect(tester.widget<BaseDetailScreen>(detail).base.id, base.id);
  return base;
}

Finder _tabLabel(String label) => find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text(label),
    );

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(_tabLabel(label));
  await tester.pumpAndSettle();
}

Finder _verticalScrollIn(Finder screen) => find.descendant(
      of: screen,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );

Finder _quickChip(String label) => find.descendant(
      of: find.byType(ExploreScreen),
      matching: find.widgetWithText(PillChip, label),
    );

Finder _quickChipsScroll() {
  final list = find.descendant(
    of: find.byType(ExploreScreen),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    ),
  );
  return find.descendant(of: list, matching: find.byType(Scrollable));
}

Future<void> _tapQuickChip(WidgetTester tester, String label) async {
  final scrollable = _quickChipsScroll();
  final scrollState = tester.state<ScrollableState>(scrollable);
  final chip = _quickChip(label);
  if (chip.evaluate().isEmpty) {
    scrollState.position.jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(
    chip,
    180,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Finder _exploreCard(String id) => find.byWidgetPredicate(
      (widget) => widget is ExploreBaseCard && widget.base.id == id,
    );

Finder _detailAction(String label) => find.byWidgetPredicate(
      (widget) => widget is OverlayIconButton && widget.label == label,
    );

Finder _sheetChip(String label, Type chipType) => find.descendant(
      of: find.byType(FiltersSheet),
      matching: find.widgetWithText(chipType, label),
    );

Future<void> _tapSheetChip(
  WidgetTester tester,
  String label,
  Type chipType,
) async {
  final chip = _sheetChip(label, chipType);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _doubleTap(WidgetTester tester, Finder target) async {
  final center = tester.getCenter(target);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(center);
  await tester.pumpAndSettle();
}

class _ClearedDetailRepository extends BaseRepository {
  _ClearedDetailRepository(this._base);

  final BaseLayout _base;

  @override
  Future<List<BaseLayout>> loadAll() async => [_base];

  @override
  String? get featuredId => _base.id;

  @override
  List<String> get trendingIds => const [];

  @override
  List<String> get recentIds => [_base.id];
}

class _FailingThenSampleRepository extends SampleBaseRepository {
  bool fail = true;
  int loadCalls = 0;

  @override
  Future<List<BaseLayout>> loadAll() async {
    loadCalls++;
    if (fail) throw StateError('catalogue unavailable');
    return super.loadAll();
  }
}

class _PendingSampleRepository extends SampleBaseRepository {
  _PendingSampleRepository(this._response);

  final Future<List<BaseLayout>> _response;

  @override
  Future<List<BaseLayout>> loadAll() => _response;
}

class _FailingFavouriteStore extends LocalStore {
  @override
  Future<void> saveFavouriteIds(List<String> ids) async {
    throw StateError('favourite write failed');
  }
}
