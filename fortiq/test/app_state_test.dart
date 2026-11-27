import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/tabs.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/models/catalogue_rights.dart';
import 'package:fortiq/data/repositories/base_repository.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _base = BaseLayout(
  id: 'test-base',
  name: 'Test Base',
  village: Village.home,
  hallLevel: 17,
  categories: ['War'],
  layoutStyle: 'Ring',
  previewSeed: 1,
  creator: Creator(name: 'Tester'),
  isSample: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('tab selection clamps stale indices to the three production tabs',
      () async {
    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);

    state.tabIndex = -1;
    expect(state.tabIndex, AppTab.home);
    state.tabIndex = 1;
    expect(state.tabIndex, AppTab.explore);
    state.tabIndex = 3;
    expect(state.tabIndex, AppTab.collections);
    state.tabIndex = 99;
    expect(state.tabIndex, AppTab.collections);
    state.tabIndex = AppTab.collections;
    expect(state.tabIndex, AppTab.collections);
  });

  test('a load completing after disposal does not notify listeners', () async {
    final pending = Completer<List<BaseLayout>>();
    final state = AppState(repository: _TestRepository(() => pending.future));

    final loading = state.load();
    state.dispose();
    pending.complete(const [_base]);

    await expectLater(loading, completes);
  });

  test('a failed catalogue load exposes an error and can be retried', () async {
    var fail = true;
    final state = AppState(
      repository: _TestRepository(() async {
        if (fail) throw StateError('catalogue unavailable');
        return const [_base];
      }),
    );

    await state.load();

    expect(state.isLoaded, isFalse);
    expect(state.loadError, isNotNull);

    fail = false;
    await state.load();

    expect(state.isLoaded, isTrue);
    expect(state.loadError, isNull);
    expect(state.bases, const [_base]);
  });

  test('search suggestions respect the active village filter', () async {
    final state = AppState(repository: SampleBaseRepository());
    addTearDown(state.dispose);
    await state.load();

    state.filters.village = Village.builder;
    state.setSearch('obsidian');

    expect(state.searchSuggestions, isEmpty);

    state.filters.village = null;
    state.notifyFilterChanged();

    expect(state.searchSuggestions, contains('Obsidian Ring'));
  });

  test('baseById preserves first-match lookup semantics', () async {
    final first = _base;
    final duplicate = _builderBase(first.id);
    final state = await _loadedState([first, duplicate]);

    expect(state.baseById(null), isNull);
    expect(state.baseById('missing'), isNull);
    expect(state.baseById(first.id), same(first));
  });

  test('Home feed follows the selected hall for real catalogue entries',
      () async {
    final state = await _loadedState([
      _realHomeBase('home-16-old', 16, DateTime.utc(2026, 1, 1)),
      _realHomeBase('home-16-new', 16, DateTime.utc(2026, 1, 3)),
      _realHomeBase('home-17-new', 17, DateTime.utc(2026, 1, 4)),
    ]);

    expect(state.featured?.id, 'home-16-new');
    expect(state.recent.map((base) => base.id), ['home-16-new', 'home-16-old']);
    expect(state.trending.map((base) => base.id), ['home-16-old']);

    state.selectHallLevel(17);
    expect(state.featured?.id, 'home-17-new');
    expect(state.recent.map((base) => base.id), ['home-17-new']);
    expect(state.trending, isEmpty);
  });

  test('Builder feed orders by rating then copies without reordering bases',
      () async {
    final home = _base;
    final low = _builderBase('low', rating: 8, copies: 1000);
    final copiesMost = _builderBase('copies-most', rating: 9, copies: 90);
    final top = _builderBase('top', rating: 10, copies: 100);
    final copiesMiddle = _builderBase('copies-middle', rating: 9, copies: 70);
    final copiesLeast = _builderBase('copies-least', rating: 9, copies: 50);
    final catalogue = [
      home,
      low,
      copiesMost,
      top,
      copiesMiddle,
      copiesLeast,
    ];
    final state = await _loadedState(catalogue);
    state.selectVillage(Village.builder);

    expect(state.featured, same(top));
    expect(
      state.trending.map((base) => base.id),
      ['copies-most', 'copies-middle', 'copies-least'],
    );
    expect(
      state.bases.map((base) => base.id),
      [
        'test-base',
        'low',
        'copies-most',
        'top',
        'copies-middle',
        'copies-least'
      ],
    );
  });

  test('Builder recent orders newest first and places undated layouts last',
      () async {
    final home = _base;
    final undated = _builderBase('undated');
    final oldest = _builderBase(
      'oldest',
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final newest = _builderBase(
      'newest',
      updatedAt: DateTime.utc(2026, 1, 3),
    );
    final state = await _loadedState([undated, home, oldest, newest]);
    state.selectVillage(Village.builder);

    expect(
      state.recent.map((base) => base.id),
      ['newest', 'oldest', 'undated'],
    );
  });

  test('Builder slices reuse their cached list instances', () async {
    final state = await _loadedState([
      _builderBase(
        'first',
        rating: 9,
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
      _builderBase(
        'second',
        rating: 8,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    state.selectVillage(Village.builder);

    final trending = state.trending;
    final recent = state.recent;

    expect(state.trending, same(trending));
    expect(state.recent, same(recent));
  });

  test(
      'catalogue caches survive unrelated search, filter, and favourite changes',
      () async {
    final state = await _loadedState([
      _builderBase(
        'first',
        rating: 9,
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
      _builderBase(
        'second',
        rating: 8,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    state.selectVillage(Village.builder);

    final trending = state.trending;
    final recent = state.recent;

    state.setSearch('no matching layout');
    expect(state.trending, same(trending));
    expect(state.recent, same(recent));

    state.filters.village = Village.home;
    state.notifyFilterChanged();
    expect(state.trending, same(trending));
    expect(state.recent, same(recent));

    await Future<void>.sync(() => state.toggleFavorite('first'));
    expect(state.isFavorite('first'), isTrue);
    expect(state.trending, same(trending));
    expect(state.recent, same(recent));
  });

  test('cached Builder slices cannot be mutated', () async {
    final state = await _loadedState([
      _builderBase(
        'first',
        rating: 9,
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
      _builderBase(
        'second',
        rating: 8,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    state.selectVillage(Village.builder);

    final trending = state.trending;
    final recent = state.recent;

    expect(() => trending.add(_base), throwsUnsupportedError);
    expect(() => recent.clear(), throwsUnsupportedError);
  });

  test('failed load and retry rebuild the catalogue index and caches',
      () async {
    var fail = true;
    final retryBase = _builderBase(
      'retry-base',
      rating: 9,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final state = AppState(
      repository: _TestRepository(() async {
        if (fail) throw StateError('catalogue unavailable');
        return [retryBase];
      }),
    );
    addTearDown(state.dispose);
    state.selectVillage(Village.builder);

    final emptyTrending = state.trending;
    final emptyRecent = state.recent;

    await state.load();
    expect(state.isLoaded, isFalse);
    expect(state.loadError, isNotNull);
    expect(state.baseById(retryBase.id), isNull);

    final failedTrending = state.trending;
    final failedRecent = state.recent;
    expect(failedTrending, isEmpty);
    expect(failedRecent, isEmpty);
    expect(failedTrending, isNot(same(emptyTrending)));
    expect(failedRecent, isNot(same(emptyRecent)));

    fail = false;
    await state.load();

    expect(state.isLoaded, isTrue);
    expect(state.loadError, isNull);
    expect(state.baseById(retryBase.id), same(retryBase));
    expect(state.featured, same(retryBase));
    expect(state.recent.single, same(retryBase));
    expect(state.trending, isNot(same(failedTrending)));
    expect(state.recent, isNot(same(failedRecent)));
  });
}

BaseLayout _realHomeBase(String id, int hallLevel, DateTime addedAt) {
  return BaseLayout(
    id: id,
    name: id,
    village: Village.home,
    hallLevel: hallLevel,
    categories: const ['War'],
    layoutStyle: '',
    previewSeed: 0,
    creator: const Creator(name: ''),
    isSample: false,
    addedAt: addedAt,
    rightsStatus: CatalogueRightsStatus.cleared,
  );
}

BaseLayout _builderBase(
  String id, {
  String creator = 'Tester',
  bool verified = false,
  double? rating,
  int? copies,
  DateTime? updatedAt,
}) {
  return BaseLayout(
    id: id,
    name: id,
    village: Village.builder,
    hallLevel: 10,
    categories: const ['War'],
    layoutStyle: 'Ring',
    previewSeed: 1,
    creator: Creator(name: creator, verified: verified),
    isSample: true,
    rating: rating,
    copies: copies,
    updatedAt: updatedAt,
  );
}

Future<AppState> _loadedState(List<BaseLayout> bases) async {
  final state = AppState(repository: _TestRepository(() async => bases));
  addTearDown(state.dispose);
  await state.load();
  return state;
}

class _TestRepository implements BaseRepository {
  _TestRepository(this._load);

  final Future<List<BaseLayout>> Function() _load;

  @override
  Future<List<BaseLayout>> loadAll() => _load();

  @override
  String? get featuredId => null;

  @override
  List<String> get trendingIds => const [];

  @override
  List<String> get recentIds => const [];

  @override
  bool get isCatalogueUnavailable => false;
}
