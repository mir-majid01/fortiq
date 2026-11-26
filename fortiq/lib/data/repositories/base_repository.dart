import '../models/base_layout.dart';
import '../sources/clash_bases_source.dart';
import '../sources/sample_base_source.dart';

/// Data access for base layouts. All UI/state reads go through this
/// interface; swapping the bundled sample dataset for a live source is a
/// one-line change in [repositoryProvider].
abstract class BaseRepository {
  /// Every base visible to the app.
  Future<List<BaseLayout>> loadAll();

  /// Curated ids powering the Home sections (design placeholder content).
  String? get featuredId;
  List<String> get trendingIds;
  List<String> get recentIds;
}

/// Chooses the active data source.
///
/// `kUseRealCatalog = true` switches every screen onto the bundled community
/// catalogue (5,162 real layouts with official in-game deep links). The
/// default keeps the approved design's placeholder content so the UI matches
/// the reference 1:1.
const bool kUseRealCatalog = false;

BaseRepository repositoryProvider() => kUseRealCatalog
    ? ClashBasesCatalogRepository()
    : SampleBaseRepository();
