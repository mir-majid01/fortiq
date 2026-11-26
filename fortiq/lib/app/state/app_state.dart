import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextEditingValue, TextSelection;
import 'package:flutter/widgets.dart' show FocusManager, TextEditingController;

import '../tabs.dart';
import '../../data/models/base_layout.dart';
import '../../data/models/filters.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/queries.dart';

/// Session state for the whole app: loaded data, navigation tab, favourites,
/// follows, and the Explore search/filter/sort pipeline. Lightweight
/// `ChangeNotifier` — no external state-management dependency needed.
class AppState extends ChangeNotifier {
  AppState({BaseRepository? repository})
      : repository = repository ?? repositoryProvider();

  final BaseRepository repository;
  bool _disposed = false;
  bool _loading = false;

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
  List<Creator>? _creatorsCache;

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
    _creatorsCache = null;
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
  bool onboarded = false;

  int _tabIndex = 0;
  int get tabIndex => _tabIndex;
  set tabIndex(int i) {
    if (_tabIndex == i) return;
    _tabIndex = i;
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

  // ---- Favourites & follows ------------------------------------------------
  final Set<String> _favoriteIds = {};
  final Set<String> _followedCreators = {};

  bool isFavorite(String id) => _favoriteIds.contains(id);
  bool isFollowing(String creator) => _followedCreators.contains(creator);

  void toggleFavorite(String id) {
    if (!_favoriteIds.remove(id)) _favoriteIds.add(id);
    notifyListeners();
  }

  void toggleFollow(String creator) {
    if (!_followedCreators.remove(creator)) _followedCreators.add(creator);
    notifyListeners();
  }

  List<BaseLayout> get favoriteBases =>
      _bases.where((b) => _favoriteIds.contains(b.id)).toList();

  /// Unique creators, verified first then by layout count.
  List<Creator> get creators {
    final cached = _creatorsCache;
    if (cached != null) return cached;
    final counts = <String, int>{};
    final verified = <String, bool>{};
    for (final b in _bases) {
      counts.update(b.creator.name, (c) => c + 1, ifAbsent: () => 1);
      verified[b.creator.name] =
          b.creator.verified || (verified[b.creator.name] ?? false);
    }
    final names = counts.keys.toList()
      ..sort((a, b) {
        final va = ((verified[a] ?? false) ? 0 : 1)
            .compareTo((verified[b] ?? false) ? 0 : 1);
        return va != 0 ? va : counts[b]!.compareTo(counts[a]!);
      });
    return _creatorsCache = List.unmodifiable([
      for (final n in names) Creator(name: n, verified: verified[n] ?? false),
    ]);
  }
}
