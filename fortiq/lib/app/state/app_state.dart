import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextEditingValue, TextSelection;
import 'package:flutter/widgets.dart' show FocusManager, TextEditingController;

import '../../core/storage/local_store.dart';
import '../../data/models/base_layout.dart';
import '../../data/models/filters.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/queries.dart';
import '../tabs.dart';

/// Session state for the whole app: loaded data, navigation tab, persisted
/// favourites, and the Explore search/filter/sort pipeline. Lightweight
/// `ChangeNotifier` — no external state-management dependency needed.
class AppState extends ChangeNotifier {
  AppState({BaseRepository? repository, LocalStore? store})
      : repository = repository ?? repositoryProvider(),
        _store = store ?? const LocalStore();

  final BaseRepository repository;
  final LocalStore _store;
  bool _disposed = false;
  bool _loading = false;
  bool _loadingPersistedState = false;
  bool _persistedStateLoaded = false;
  Future<void>? _persistedStateRestoration;
  Future<void> _favouriteWriteQueue = Future<void>.value();

  @override
  void dispose() {
    _disposed = true;
    searchController.dispose();
    super.dispose();
  }

  // ---- Data ---------------------------------------------------------------
  List<BaseLayout> _bases = const [];
  bool _loaded = false;
  String? _loadError;
  Map<String, BaseLayout> _baseIndex = const {};
  List<BaseLayout>? _builderFeedCache;
  List<BaseLayout>? _builderRecentCache;
  List<BaseLayout>? _builderTrendingCache;
  List<BaseLayout>? _builderRecentSelectionCache;

  List<BaseLayout> get bases => _bases;
  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  String? get loadError => _loadError;

  BaseLayout? baseById(String? id) {
    if (id == null) return null;
    return _baseIndex[id];
  }

  void _invalidateCatalogueCaches() {
    final index = <String, BaseLayout>{};
    for (final base in _bases) {
      index.putIfAbsent(base.id, () => base);
    }
    _baseIndex = Map.unmodifiable(index);
    _builderFeedCache = null;
    _builderRecentCache = null;
    _builderTrendingCache = null;
    _builderRecentSelectionCache = null;
  }

  Future<void> load() async {
    if (_disposed || _loaded || _loading) return;
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final bases = await repository.loadAll();
      if (_disposed) return;
      _bases = bases;
      _loaded = true;
      _invalidateCatalogueCaches();
    } catch (e) {
      if (_disposed) return;
      _bases = const [];
      _loadError = 'The base catalogue could not be loaded.';
      _invalidateCatalogueCaches();
      debugPrint('Fortiq: catalogue load failed — $e');
    } finally {
      if (!_disposed) {
        _loading = false;
        _invalidateResults();
        notifyListeners();
      }
    }
  }

  // ---- Flow ---------------------------------------------------------------
  bool _onboarded = false;
  bool get onboarded => _onboarded;
  bool get isRestoringPersistedState => _loadingPersistedState;
  bool get isPersistedStateLoaded => _persistedStateLoaded;

  /// Loads onboarding and favourite IDs once. Concurrent callers share the
  /// same restoration so a favourite edit cannot race ahead of saved IDs.
  Future<void> loadPersistedState() {
    if (_disposed || _persistedStateLoaded) return Future<void>.value();
    final pending = _persistedStateRestoration;
    if (pending != null) return pending;

    late final Future<void> restoration;
    restoration = _restorePersistedState().whenComplete(() {
      if (identical(_persistedStateRestoration, restoration)) {
        _persistedStateRestoration = null;
      }
    });
    _persistedStateRestoration = restoration;
    return restoration;
  }

  Future<void> _restorePersistedState() async {
    _loadingPersistedState = true;
    try {
      final complete = await _store.loadOnboardingComplete();
      final favouriteIds = await _store.loadFavouriteIds();
      if (_disposed) return;
      _onboarded = complete;
      _favoriteIds
        ..clear()
        ..addAll(favouriteIds);
      _persistedStateLoaded = true;
      notifyListeners();
    } finally {
      if (!_disposed) _loadingPersistedState = false;
    }
  }

  /// Called only by the onboarding Finish/Skip callback. The session changes
  /// only after LocalStore has accepted the write. A failed preference read
  /// does not prevent onboarding completion, but favourite edits still retry
  /// restoration rather than overwriting IDs that could not be read.
  Future<void> completeOnboarding() async {
    if (_disposed || _onboarded) return;
    try {
      await loadPersistedState();
    } catch (_) {
      // Onboarding can still be completed; the root already handles read
      // failures and subsequent favourite edits will retry restoration.
    }
    if (_disposed || _onboarded) return;
    await _store.completeOnboarding();
    if (_disposed) return;
    _onboarded = true;
    notifyListeners();
  }

  int _tabIndex = 0;
  int get tabIndex => _tabIndex;
  set tabIndex(int i) {
    final clamped = i < AppTab.home
        ? AppTab.home
        : i > AppTab.collections
            ? AppTab.collections
            : i;
    if (_tabIndex == clamped) return;
    _tabIndex = clamped;
    notifyListeners();
  }

  // ---- Village & hall selection (Home) ------------------------------------
  Village _village = Village.home;
  Village get village => _village;

  int _hallLevel = 16;
  int get hallLevel => _hallLevel;

  void selectVillage(Village v) {
    if (_village == v) return;
    _village = v;
    _hallLevel = v.maxHall;
    notifyListeners();
  }

  void selectHallLevel(int level) {
    if (_hallLevel == level) return;
    _hallLevel = level;
    notifyListeners();
  }

  String get greetingTitle =>
      'Fresh ${_village.hallPrefix} $_hallLevel layouts today';

  /// Opens Explore scoped to the Home selection — the chosen village and hall
  /// level, narrowed to [category] when a category pill was tapped.
  void openExploreFromHome({String? category}) {
    filters
      ..reset()
      ..village = _village
      ..hallLevels = {_hallLevel};
    if (category != null) filters.categories = {category};
    _tabIndex = AppTab.explore;
    _invalidateResults();
    notifyListeners();
  }

  // ---- Explore search / filters / sort -------------------------------------
  /// Single source of truth for the search box text.
  final TextEditingController searchController = TextEditingController();

  String get query => searchController.text;

  final ExploreFilters filters = ExploreFilters();
  BaseSort _sort = BaseSort.topRated;
  BaseSort get sort => _sort;

  List<BaseLayout>? _results;
  List<String> _suggestions = const [];
  bool _suggestionsValid = false;

  void _invalidateResults() {
    _results = null;
    _suggestionsValid = false;
  }

  void setQuery(String _) => _searchChanged();

  /// Replaces the search text (suggestion tap, clear button, Home handoff).
  /// The keyboard is dismissed so the results are visible.
  void setSearch(String value) {
    searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _searchChanged();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void clearSearch() {
    if (searchController.text.isEmpty) return;
    searchController.clear();
    _searchChanged();
  }

  void _searchChanged() {
    _invalidateResults();
    notifyListeners();
  }

  void setSort(BaseSort s) {
    if (_sort == s) return;
    _sort = s;
    _invalidateResults();
    notifyListeners();
  }

  /// Commits the filter sheet's draft.
  void applyFilters(ExploreFilters draft) {
    filters.village = draft.village;
    filters.hallLevels = {...draft.hallLevels};
    filters.categories = {...draft.categories};
    filters.styles = {...draft.styles};
    filters.freshness = draft.freshness;
    filters.verifiedOnly = draft.verifiedOnly;
    _invalidateResults();
    notifyListeners();
  }

  /// Re-runs Explore after the quick chips have mutated [filters] directly.
  void notifyFilterChanged() {
    _invalidateResults();
    notifyListeners();
  }

  /// Explore results for the current search, filters and sort.
  /// Computed once per change, not per rebuild.
  List<BaseLayout> get exploreResults {
    final cached = _results;
    if (cached != null) return cached;
    final results = queryBases(
      _bases,
      query: query,
      filters: filters,
      sort: _sort,
    );
    _results = results;
    return results;
  }

  /// Up to four base names and two creators matching the current search.
  List<String> get searchSuggestions {
    if (_suggestionsValid) return _suggestions;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _suggestions = const [];
    } else {
      final names = <String>[];
      final creators = <String>[];
      for (final b in exploreResults) {
        if (names.length < 4 && b.name.toLowerCase().contains(q)) {
          names.add(b.name);
        }
        if (creators.length < 2 &&
            b.creator.name.toLowerCase().contains(q) &&
            !creators.contains(b.creator.name)) {
          creators.add(b.creator.name);
        }
        if (names.length >= 4 && creators.length >= 2) break;
      }
      _suggestions = [...names, ...creators];
    }
    _suggestionsValid = true;
    return _suggestions;
  }

  // ---- Home feed -----------------------------------------------------------
  /// The curated design picks cover the Home Village. For the Builder Base,
  /// picks are derived from the dataset: best rated, then most copied.
  List<BaseLayout> get _builderFeed {
    final cached = _builderFeedCache;
    if (cached != null) return cached;
    final feed = [
      ..._bases.where((b) => b.village == Village.builder),
    ]..sort((a, b) {
        final byRating = (b.rating ?? -1).compareTo(a.rating ?? -1);
        return byRating != 0
            ? byRating
            : (b.copies ?? 0).compareTo(a.copies ?? 0);
      });
    return _builderFeedCache = List.unmodifiable(feed);
  }

  List<BaseLayout> get _builderRecent {
    final cached = _builderRecentCache;
    if (cached != null) return cached;
    final recent = [
      ..._bases.where((b) => b.village == Village.builder),
    ]..sort((a, b) =>
        (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return _builderRecentCache = List.unmodifiable(recent);
  }

  BaseLayout? get featured {
    if (_village == Village.builder) {
      final feed = _builderFeed;
      return feed.isEmpty ? null : feed.first;
    }
    return baseById(repository.featuredId);
  }

  List<BaseLayout> get trending {
    if (_village == Village.builder) {
      return _builderTrendingCache ??= List.unmodifiable(
        _builderFeed.skip(1).take(3),
      );
    }
    return [
      for (final id in repository.trendingIds)
        if (baseById(id) case final base?) base,
    ];
  }

  List<BaseLayout> get recent {
    if (_village == Village.builder) {
      return _builderRecentSelectionCache ??=
          List.unmodifiable(_builderRecent.take(3));
    }
    return [
      for (final id in repository.recentIds)
        if (baseById(id) case final base?) base,
    ];
  }

  // ---- Favourites ----------------------------------------------------------
  final Set<String> _favoriteIds = {};

  /// Saved IDs in insertion order, including IDs absent from the catalogue.
  Set<String> get favoriteIds => Set<String>.unmodifiable(_favoriteIds);

  bool isFavorite(String id) => _favoriteIds.contains(id);

  /// Persists a toggle before committing it to session state. Writes are
  /// serialized so concurrent edits cannot overwrite each other's snapshots.
  Future<void> toggleFavorite(String id) {
    final operation = _favouriteWriteQueue.then((_) => _persistFavorite(id));
    _favouriteWriteQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> _persistFavorite(String id) async {
    if (_disposed) return;
    await loadPersistedState();
    if (_disposed) return;

    final next = {..._favoriteIds};
    if (!next.remove(id)) next.add(id);
    await _store.saveFavouriteIds(next.toList(growable: false));
    if (_disposed) return;

    _favoriteIds
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  List<BaseLayout> get favoriteBases =>
      _bases.where((b) => _favoriteIds.contains(b.id)).toList();
}
