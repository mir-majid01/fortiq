import 'dart:io';

import '../models/base_layout.dart';
import 'base_repository.dart';
import 'imported_base_store.dart';

class CompositeBaseRepository implements BaseRepository {
  CompositeBaseRepository({
    required this.remote,
    required this.imports,
  });

  final BaseRepository remote;
  final ImportedBaseStore imports;

  List<BaseLayout>? _cache;
  List<String>? _recent;

  @override
  Future<List<BaseLayout>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    final remoteBases = await remote.loadAll();
    final importedBases = await imports.load();
    final ids = <String>{};
    final links = <String>{};
    final previews = <String>{};
    for (final base in [...remoteBases, ...importedBases]) {
      if (!ids.add(base.id) ||
          (base.gameLink != null && !links.add(base.gameLink!)) ||
          (base.imageUrl != null && !previews.add(base.imageUrl!)) ||
          (base.localImagePath != null &&
              !previews.add(base.localImagePath!))) {
        throw StateError('Duplicate catalogue content: ${base.id}');
      }
    }
    _cache = List.unmodifiable([...remoteBases, ...importedBases]);
    _deriveRecent(_cache!);
    return _cache!;
  }

  Future<BaseLayout> importBase({
    required String link,
    required String name,
    String? attribution,
    String? description,
    required File preview,
  }) async {
    final remoteBases = _cache ?? await remote.loadAll();
    if (remoteBases.any((base) => base.gameLink == link.trim())) {
      throw StateError(
          'This official layout link is already in the catalogue.');
    }
    final base = await imports.importBase(
      link: link,
      name: name,
      attribution: attribution,
      description: description,
      preview: preview,
    );
    _cache = null;
    _recent = null;
    return base;
  }

  Future<void> deleteImportedBase(String id) async {
    await imports.delete(id);
    _cache = null;
    _recent = null;
  }

  void _deriveRecent(List<BaseLayout> bases) {
    final byNewest = [...bases]..sort((a, b) {
        final at = a.addedAt;
        final bt = b.addedAt;
        if (at == null && bt == null) return a.id.compareTo(b.id);
        if (at == null) return 1;
        if (bt == null) return -1;
        final byDate = bt.compareTo(at);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    _recent = List.unmodifiable(byNewest.take(6).map((base) => base.id));
  }

  @override
  bool get isCatalogueUnavailable => _cache?.isEmpty ?? false;

  @override
  String? get featuredId => remote.featuredId;

  @override
  List<String> get trendingIds => remote.trendingIds;

  @override
  List<String> get recentIds => _recent ?? const [];
}
