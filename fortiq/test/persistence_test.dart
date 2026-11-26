import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/app.dart';
import 'package:fortiq/app/router.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/core/storage/local_store.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/repositories/base_repository.dart';
import 'package:fortiq/features/onboarding/onboarding_screen.dart';
import 'package:fortiq/features/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingKey = 'fortiq.onboarding.completed.v1';
const _favouritesKey = 'fortiq.favourites.ids.v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first launch defaults to incomplete without writing completion',
      () async {
    const store = LocalStore();

    expect(await store.loadOnboardingComplete(), isFalse);
    expect(await store.loadFavouriteIds(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_onboardingKey), isNull);
    expect(prefs.getStringList(_favouritesKey), isNull);
  });

  test('malformed versioned values safely use first-launch defaults', () async {
    SharedPreferences.setMockInitialValues({
      _onboardingKey: 'not-a-bool',
      _favouritesKey: 'not-a-list',
    });
    const store = LocalStore();

    expect(await store.loadOnboardingComplete(), isFalse);
    expect(await store.loadFavouriteIds(), isEmpty);
  });

  test('loaded favourite IDs cannot mutate the stored snapshot', () async {
    SharedPreferences.setMockInitialValues({
      _favouritesKey: <String>['obsidian-ring'],
    });
    final ids = await const LocalStore().loadFavouriteIds();

    expect(() => ids.add('injected'), throwsUnsupportedError);
    expect(await const LocalStore().loadFavouriteIds(), ['obsidian-ring']);
  });

  test('a fresh AppState remains incomplete and does not write preferences',
      () async {
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
    );
    addTearDown(state.dispose);

    expect(state.onboarded, isFalse);
    await state.loadPersistedState();
    expect(state.onboarded, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_onboardingKey), isNull);
  });

  test('favourites restore once with Set uniqueness and keep stale IDs',
      () async {
    SharedPreferences.setMockInitialValues({
      _favouritesKey: ['test-base', 'retired-base', 'test-base'],
    });
    final store = _ControlledStore();
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);

    await state.loadPersistedState();
    await state.loadPersistedState();

    expect(store.favouriteLoadCalls, 1);
    expect(state.isFavorite('test-base'), isTrue);
    expect(state.isFavorite('retired-base'), isTrue);

    await Future<void>.sync(() => state.toggleFavorite('test-base'));
    expect(state.isFavorite('test-base'), isFalse);
    expect(state.isFavorite('retired-base'), isTrue);
    expect(await const LocalStore().loadFavouriteIds(), ['retired-base']);
  });

  test('favourite toggles write unique snapshots through LocalStore', () async {
    final store = _ControlledStore();
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);
    await state.loadPersistedState();

    await Future<void>.sync(() => state.toggleFavorite('test-base'));
    expect(state.isFavorite('test-base'), isTrue);
    expect(store.lastSavedFavouriteIds, ['test-base']);
    expect(await const LocalStore().loadFavouriteIds(), ['test-base']);

    await Future<void>.sync(() => state.toggleFavorite('test-base'));
    expect(state.isFavorite('test-base'), isFalse);
    expect(store.lastSavedFavouriteIds, isEmpty);
    expect(await const LocalStore().loadFavouriteIds(), isEmpty);
  });

  test('a blocked favourite write does not commit session state early',
      () async {
    final store = _ControlledStore(blockWrites: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);
    await state.loadPersistedState();

    var returned = false;
    final toggle = Future<void>.sync(() => state.toggleFavorite('test-base'))
        .then((_) => returned = true);
    await Future<void>.delayed(Duration.zero);

    expect(store.favouriteSaveCalls, 1);
    expect(returned, isFalse);
    expect(state.isFavorite('test-base'), isFalse);

    store.releaseWrites();
    await toggle;
    expect(returned, isTrue);
    expect(state.isFavorite('test-base'), isTrue);
  });

  test('a failed favourite write leaves AppState and storage unchanged',
      () async {
    final store = _ControlledStore(failWrites: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);
    await state.loadPersistedState();

    await expectLater(
      Future<void>.sync(() => state.toggleFavorite('test-base')),
      throwsStateError,
    );

    expect(state.isFavorite('test-base'), isFalse);
    expect(await const LocalStore().loadFavouriteIds(), isEmpty);
  });

  test('a failed unfavourite leaves the saved ID and storage unchanged',
      () async {
    SharedPreferences.setMockInitialValues({
      _favouritesKey: ['saved-base'],
    });
    final store = _ControlledStore(failWrites: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);
    await state.loadPersistedState();

    await expectLater(
      Future<void>.sync(() => state.toggleFavorite('saved-base')),
      throwsStateError,
    );

    expect(state.isFavorite('saved-base'), isTrue);
    expect(await const LocalStore().loadFavouriteIds(), ['saved-base']);
  });

  test('a favourite edit waits for the in-flight restoration', () async {
    SharedPreferences.setMockInitialValues({
      _favouritesKey: ['saved-base'],
    });
    final store = _ControlledStore(blockReads: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);

    final restoration = state.loadPersistedState();
    final toggle = Future<void>.sync(() => state.toggleFavorite('test-base'));
    await Future<void>.delayed(Duration.zero);

    expect(store.favouriteSaveCalls, 0);
    expect(state.isFavorite('test-base'), isFalse);

    store.releaseReads();
    await restoration;
    await toggle;

    expect(store.favouriteLoadCalls, 1);
    expect(state.isFavorite('saved-base'), isTrue);
    expect(state.isFavorite('test-base'), isTrue);
    expect(
      await const LocalStore().loadFavouriteIds(),
      ['saved-base', 'test-base'],
    );
  });

  test('concurrent favourite writes are serialized without lost IDs', () async {
    final store = _ControlledStore(blockWrites: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);
    await state.loadPersistedState();

    final first = Future<void>.sync(() => state.toggleFavorite('test-base'));
    final second = Future<void>.sync(() => state.toggleFavorite('second-base'));
    await Future<void>.delayed(Duration.zero);
    expect(store.favouriteSaveCalls, 1);

    store.releaseWrites();
    await Future.wait([first, second]);

    expect(store.favouriteSaveCalls, 2);
    expect(state.isFavorite('test-base'), isTrue);
    expect(state.isFavorite('second-base'), isTrue);
    expect(
      await const LocalStore().loadFavouriteIds(),
      ['test-base', 'second-base'],
    );
  });

  test('completing onboarding does not skip favourite restoration', () async {
    SharedPreferences.setMockInitialValues({
      _favouritesKey: ['saved-base'],
    });
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
    );
    addTearDown(state.dispose);

    await state.completeOnboarding();
    await Future<void>.sync(() => state.toggleFavorite('test-base'));

    expect(state.isFavorite('saved-base'), isTrue);
    expect(state.isFavorite('test-base'), isTrue);
    expect(
      await const LocalStore().loadFavouriteIds(),
      ['saved-base', 'test-base'],
    );
  });

  test('completing onboarding is persisted before completion returns',
      () async {
    final store = _ControlledStore(blockWrites: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);
    await state.loadPersistedState();

    var returned = false;
    final completion = state.completeOnboarding().then((_) {
      returned = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(store.completeCalls, 1);
    expect(returned, isFalse);
    expect(state.onboarded, isFalse);

    store.releaseWrites();
    await completion;

    expect(returned, isTrue);
    expect(state.onboarded, isTrue);
    expect(await const LocalStore().loadOnboardingComplete(), isTrue);
  });

  test('recreated AppState restores completion after a fresh service instance',
      () async {
    final first = AppState(
      repository: _TestRepository(() async => const [_base]),
    );
    await first.completeOnboarding();
    first.dispose();

    final recreated = AppState(
      repository: _TestRepository(() async => const [_base]),
    );
    addTearDown(recreated.dispose);
    await recreated.loadPersistedState();

    expect(recreated.onboarded, isTrue);
    expect(
      await const LocalStore().loadOnboardingComplete(),
      isTrue,
      reason: 'completion must survive process recreation, not just a widget',
    );
  });

  test('failed onboarding write does not complete session state', () async {
    final store = _ControlledStore(failWrites: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);

    await expectLater(state.completeOnboarding(), throwsStateError);

    expect(state.onboarded, isFalse);
    expect(await const LocalStore().loadOnboardingComplete(), isFalse);
  });

  test('failed favourite write is reported instead of silently succeeding',
      () async {
    final store = _ControlledStore(failWrites: true);

    await expectLater(
      store.saveFavouriteIds(const ['obsidian-ring']),
      throwsStateError,
    );
    expect(await const LocalStore().loadFavouriteIds(), isEmpty);
  });

  test('favourite IDs round-trip through versioned storage', () async {
    const store = LocalStore();

    await store.saveFavouriteIds(const ['obsidian-ring', 'ashfall-core']);

    expect(
      await const LocalStore().loadFavouriteIds(),
      ['obsidian-ring', 'ashfall-core'],
    );

    await store.saveFavouriteIds(const []);
    expect(await const LocalStore().loadFavouriteIds(), isEmpty);
  });

  testWidgets('root waits for preferences before leaving splash',
      (tester) async {
    final store = _ControlledStore(blockReads: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(FortiqApp(state: state));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(MainShell), findsNothing);

    await tester.pump(SplashScreen.duration);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(store.loadCalls, 1,
        reason:
            'restoration starts immediately but cannot finish while blocked');

    store.releaseReads();
    await tester.pump();
    expect(store.loadCalls, 1);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(StateScope.of(tester.element(find.byType(OnboardingScreen))),
        same(state));
    expect(state.onboarded, isFalse);
  });

  testWidgets(
      'failed preference read falls back to onboarding without uncaught error',
      (tester) async {
    final store = _ControlledStore(failReads: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(FortiqApp(state: state));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'a read failure must be handled before the splash completes');

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(state.onboarded, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch shows onboarding after splash', (tester) async {
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(FortiqApp(state: state));
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(state.onboarded, isFalse);
  });

  testWidgets('onboarding pages do not complete before Finish or Skip',
      (tester) async {
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(FortiqApp(state: state));
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh layouts for every meta shift'), findsOneWidget);
    expect(state.onboarded, isFalse);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('From Fortiq straight into your village'), findsOneWidget);
    expect(state.onboarded, isFalse);
    expect(find.byType(MainShell), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_onboardingKey), isNull);
  });

  testWidgets('Skip awaits persistence before transitioning to MainShell',
      (tester) async {
    final store = _ControlledStore(blockWrites: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(FortiqApp(state: state));
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(store.completeCalls, 1);
    expect(state.onboarded, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);

    store.releaseWrites();
    await tester.pumpAndSettle();

    expect(state.onboarded, isTrue);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('Finish awaits persistence before transitioning to MainShell',
      (tester) async {
    final store = _ControlledStore(blockWrites: true);
    final state = AppState(
      repository: _TestRepository(() async => const [_base]),
      store: store,
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(FortiqApp(state: state));
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(store.completeCalls, 1);
    expect(state.onboarded, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    store.releaseWrites();
    await tester.pumpAndSettle();

    expect(state.onboarded, isTrue);
    expect(find.byType(MainShell), findsOneWidget);
    expect(await const LocalStore().loadOnboardingComplete(), isTrue);
  });

  testWidgets('normal restart opens MainShell after the restored splash',
      (tester) async {
    await const LocalStore().completeOnboarding();
    final restarted = AppState(
      repository: _TestRepository(() async => const [_base]),
    );
    addTearDown(restarted.dispose);

    await tester.pumpWidget(FortiqApp(state: restarted));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(MainShell), findsOneWidget);
    expect(restarted.onboarded, isTrue);
  });
}

class _TestRepository implements BaseRepository {
  _TestRepository(this._load);

  final Future<List<BaseLayout>> Function() _load;

  @override
  Future<List<BaseLayout>> loadAll() => _load();

  @override
  String? get featuredId => null;

  @override
  List<String> get recentIds => const [];

  @override
  List<String> get trendingIds => const [];
}

class _ControlledStore extends LocalStore {
  _ControlledStore(
      {this.blockReads = false,
      this.blockWrites = false,
      this.failReads = false,
      this.failWrites = false});

  final bool blockReads;
  bool blockWrites;
  final bool failReads;
  final bool failWrites;
  final _readGate = Completer<void>();
  final _writeGate = Completer<void>();
  int loadCalls = 0;
  int completeCalls = 0;
  int favouriteLoadCalls = 0;
  int favouriteSaveCalls = 0;
  List<String>? lastSavedFavouriteIds;

  void releaseReads() {
    if (!_readGate.isCompleted) _readGate.complete();
  }

  void releaseWrites() {
    if (!_writeGate.isCompleted) _writeGate.complete();
  }

  @override
  Future<bool> loadOnboardingComplete() async {
    loadCalls++;
    if (blockReads) await _readGate.future;
    if (failReads) throw StateError('preference read failed');
    return super.loadOnboardingComplete();
  }

  @override
  Future<void> completeOnboarding() async {
    completeCalls++;
    if (blockWrites) await _writeGate.future;
    if (failWrites) throw StateError('preference write failed');
    await super.completeOnboarding();
  }

  @override
  Future<List<String>> loadFavouriteIds() async {
    favouriteLoadCalls++;
    if (blockReads) await _readGate.future;
    if (failReads) throw StateError('preference read failed');
    return super.loadFavouriteIds();
  }

  @override
  Future<void> saveFavouriteIds(List<String> ids) async {
    favouriteSaveCalls++;
    if (blockWrites) await _writeGate.future;
    if (failWrites) throw StateError('preference write failed');
    await super.saveFavouriteIds(ids);
    lastSavedFavouriteIds = List<String>.unmodifiable(ids);
  }
}

const _base = BaseLayout(
  id: 'test-base',
  name: 'Test Base',
  village: Village.home,
  hallLevel: 16,
  categories: ['War'],
  layoutStyle: 'Ring',
  previewSeed: 1,
  creator: Creator(name: 'Tester'),
  isSample: true,
);
