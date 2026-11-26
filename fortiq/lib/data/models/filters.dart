/// Explore filtering and sorting models.
library;

import 'base_layout.dart';

const List<String> baseCategories = [
  'War',
  'CWL',
  'Trophy',
  'Farming',
  'Hybrid',
  'Anti 3 Star',
  'Legend League',
  'Ranked',
];

/// Freshness options in the filter sheet.
enum Freshness { any, sevenDays, thirtyDays, currentMeta }

extension FreshnessX on Freshness {
  String get label => switch (this) {
        Freshness.any => 'Any',
        Freshness.sevenDays => '7 days',
        Freshness.thirtyDays => '30 days',
        Freshness.currentMeta => 'Current meta',
      };

  /// Maximum age in days a layout may have — lower is fresher.
  int get maxAgeDays => switch (this) {
        Freshness.any => 1 << 30,
        Freshness.sevenDays => 7,
        Freshness.thirtyDays => 30,
        Freshness.currentMeta => 7,
      };
}

/// Result ordering for Explore.
enum BaseSort { topRated, mostCopied, newest }

extension BaseSortX on BaseSort {
  String get label => switch (this) {
        BaseSort.topRated => 'Top rated',
        BaseSort.mostCopied => 'Most copied',
        BaseSort.newest => 'Newest',
      };
}

/// Full filter state driving Explore results. Selections are functional —
/// [matches] decides which bases are shown.
class ExploreFilters {
  ExploreFilters({
    Village? village = Village.home,
    Set<int>? hallLevels,
    Set<String>? categories,
    Set<String>? styles,
    this.freshness = Freshness.any,
    this.verifiedOnly = false,
  })  : _village = village,
        hallLevels = hallLevels ?? {},
        categories = categories ?? {},
        styles = styles ?? {};

  /// Village scope, or `null` for both villages (the Explore "All" chip).
  Village? _village;
  Village? get village => _village;
  set village(Village? value) {
    if (_village == value) return;
    _village = value;
    hallLevels = {};
  }
  Set<int> hallLevels;
  Set<String> categories;
  Set<String> styles;
  Freshness freshness;
  bool verifiedOnly;

  /// The default view: Home Village, nothing else restricted.
  bool get isDefault =>
      village == Village.home &&
      hallLevels.isEmpty &&
      categories.isEmpty &&
      styles.isEmpty &&
      freshness == Freshness.any &&
      !verifiedOnly;

  /// Number of filter groups touched — drives the badge on the Filters
  /// button. Both-villages is not a restriction, so it does not count.
  int get activeGroupCount =>
      (village != null && village != Village.home ? 1 : 0) +
      (hallLevels.isNotEmpty ? 1 : 0) +
      (categories.isNotEmpty ? 1 : 0) +
      (styles.isNotEmpty ? 1 : 0) +
      (freshness != Freshness.any ? 1 : 0) +
      (verifiedOnly ? 1 : 0);

  void reset() {
    village = Village.home;
    hallLevels = {};
    categories = {};
    styles = {};
    freshness = Freshness.any;
    verifiedOnly = false;
  }

  /// A deep copy (the filter sheet edits a draft without mutating state).
  ExploreFilters copy() => ExploreFilters(
        village: village,
        hallLevels: {...hallLevels},
        categories: {...categories},
        styles: {...styles},
        freshness: freshness,
        verifiedOnly: verifiedOnly,
      );

  bool matches(BaseLayout b) {
    final v = village;
    if (v != null && b.village != v) return false;
    if (hallLevels.isNotEmpty && !hallLevels.contains(b.hallLevel)) {
      return false;
    }
    if (categories.isNotEmpty && !b.categories.any(categories.contains)) {
      return false;
    }
    if (styles.isNotEmpty && !styles.contains(b.layoutStyle)) return false;
    if (verifiedOnly && !b.creator.verified) return false;
    if (freshness != Freshness.any) {
      final updated = b.updatedAt;
      if (updated == null) return false;
      final age = DateTime.now().difference(updated).inDays;
      if (age > freshness.maxAgeDays) return false;
    }
    return true;
  }
}
