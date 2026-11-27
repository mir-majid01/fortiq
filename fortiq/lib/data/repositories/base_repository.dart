import '../models/base_layout.dart';
import '../sources/clash_bases_source.dart';
import 'composite_base_repository.dart';
import 'imported_base_store.dart';

/// Data access for base layouts. All UI/state reads go through this interface.
abstract class BaseRepository {
  /// Every rights-cleared base visible to the app.
  Future<List<BaseLayout>> loadAll();

  /// True after a successful load when no publishable entries are available.
  bool get isCatalogueUnavailable => false;

  /// Curated ids powering the Home sections when supported by the source.
  String? get featuredId;
  List<String> get trendingIds;
  List<String> get recentIds;
}

/// Production always uses the rights-gated catalogue. Sample content is
/// injected explicitly by reference/golden tests and is never a fallback.
BaseRepository repositoryProvider() => CompositeBaseRepository(
      remote: ClashBasesCatalogRepository(),
      imports: ImportedBaseStore(),
    );
