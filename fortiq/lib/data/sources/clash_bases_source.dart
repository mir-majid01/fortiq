import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/base_layout.dart';
import '../repositories/base_repository.dart';

/// Production data path: the bundled community catalogue
/// (`assets/data/clash_bases_catalog.json` — the `clash-bases` repository's
/// `bases.json`, 5,162 layouts credited to their upstream builders).
///
/// Every entry carries the official `link.clashofclans.com` deep link, so
/// "Open in Game" works out of the box in this mode. Live statistics (rating,
/// copy count) do not exist in the catalogue — those fields stay null and the
/// UI degrades gracefully.
class ClashBasesCatalogRepository implements BaseRepository {
  ClashBasesCatalogRepository();

  static const String _assetPath = 'assets/data/clash_bases_catalog.json';

  List<BaseLayout>? _cache;
  List<String>? _trending;
  List<String>? _recent;

  @override
  Future<List<BaseLayout>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = await compute(_decodeBases, raw);
    final bases = decoded.map(fromJson).toList(growable: false);
    _cache = bases;
    _deriveCurated(bases);
    return bases;
  }

  static List<Map<String, Object?>> _decodeBases(String raw) {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    return (parsed['bases'] as List<dynamic>)
        .map((e) => Map<String, Object?>.from(e as Map<dynamic, dynamic>))
        .toList(growable: false);
  }

  void _deriveCurated(List<BaseLayout> bases) {
    final byNewest = [...bases]
      ..sort((a, b) => (b.updatedAt ?? DateTime(2000))
          .compareTo(a.updatedAt ?? DateTime(2000)));
    String? idAt(int i) =>
        byNewest.length > i ? byNewest[i].id : null;
    _trending = [
      if (idAt(1) != null) idAt(1)!,
      if (idAt(2) != null) idAt(2)!,
      if (idAt(3) != null) idAt(3)!,
    ];
    _recent = [
      if (idAt(4) != null) idAt(4)!,
      if (idAt(5) != null) idAt(5)!,
      if (idAt(6) != null) idAt(6)!,
    ];
  }

  @override
  String? get featuredId {
    final list = _cache;
    if (list == null || list.isEmpty) return null;
    // Most recently added layout fronts the featured card.
    final newest = list.reduce((a, b) =>
        (b.updatedAt ?? DateTime(2000)).isAfter(a.updatedAt ?? DateTime(2000))
            ? b
            : a);
    return newest.id;
  }

  @override
  List<String> get trendingIds => _trending ?? const [];

  @override
  List<String> get recentIds => _recent ?? const [];

  static BaseLayout fromJson(Map<String, Object?> json) {
    final id = json['id'] as String? ?? '';
    final th = (json['town_hall'] as num?)?.toInt() ?? 0;
    final type = json['type'] as String? ?? 'War';
    final builderRaw = json['builder'] as String? ?? 'Community';
    // builder looks like "repo/source (note)" — keep the credited source.
    final creatorName = builderRaw.split('(').first.trim();
    final addedRaw = json['added'] as String?;
    DateTime? added;
    if (addedRaw != null) {
      added = DateTime.tryParse(addedRaw);
    }
    final tags = (json['tags'] as List<dynamic>? ?? [])
        .map((t) => t.toString())
        .toList(growable: false);

    return BaseLayout(
      id: id,
      name: _stripThSuffix(json['name'] as String? ?? 'Layout'),
      village: Village.home,
      hallLevel: th,
      categories: [type],
      layoutStyle: _styles[(tags.join().hashCode).abs() % _styles.length],
      // Stable pseudo-random seed derived from the id.
      previewSeed: (id.hashCode).abs() % 99 + 1,
      imageUrl: json['image'] as String?,
      creator: Creator(name: creatorName.isEmpty ? 'Community' : creatorName),
      updatedAt: added,
      verified: false,
      gameLink: json['link'] as String?,
      description: json['description'] as String?,
      isSample: false,
    );
  }

  static String _stripThSuffix(String name) {
    final idx = name.lastIndexOf('(TH');
    return idx > 0 ? name.substring(0, idx).trim() : name;
  }

  static const List<String> _styles = [
    'Box', 'Diamond', 'Ring', 'Island', 'Symmetrical', 'Asymmetrical',
  ];
}
