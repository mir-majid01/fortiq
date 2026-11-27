import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/base_layout.dart';
import '../models/catalogue_rights.dart';
import '../repositories/base_repository.dart';

/// Production catalogue path. Only records whose source has explicit content
/// and preview redistribution grants are returned. The upstream software MIT
/// licence is retained in the manifest, but is not treated as permission to
/// redistribute third-party base designs or previews.
class ClashBasesCatalogRepository implements BaseRepository {
  ClashBasesCatalogRepository({
    AssetBundle? assetBundle,
    this.catalogueAssetPath = defaultCatalogueAssetPath,
    this.rightsManifestAssetPath = defaultRightsManifestAssetPath,
  }) : _assetBundle = assetBundle ?? rootBundle;

  static const String defaultCatalogueAssetPath =
      'assets/data/cleared_catalogue.json';
  static const String defaultRightsManifestAssetPath =
      'assets/data/catalogue_rights.json';
  static const String defaultSourceId = 'clash-bases';

  final AssetBundle _assetBundle;
  final String catalogueAssetPath;
  final String rightsManifestAssetPath;

  List<BaseLayout>? _cache;
  List<String>? _recent;

  @override
  Future<List<BaseLayout>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    final manifestRaw = await _assetBundle.loadString(rightsManifestAssetPath);
    final manifestJson = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final manifest = CatalogueRightsManifest.fromJson(manifestJson);
    final raw = await _assetBundle.loadString(catalogueAssetPath);
    final records = raw.length < 64 * 1024
        ? _decodeBases(raw)
        : await compute(_decodeBases, raw);
    final rightsBySource = {
      for (final source in manifest.sources) source.id: source
    };

    final cleared = <Map<String, Object?>>[];
    for (final record in records) {
      final sourceId = _sourceId(record);
      final rights = rightsBySource[sourceId];
      if (rights == null || !rights.isCleared) continue;
      cleared.add(record);
    }
    _assertNoDuplicateContent(cleared);

    final bases = cleared
        .map((record) => fromJson(
              record,
              sourceId: _sourceId(record),
              rightsStatus: CatalogueRightsStatus.cleared,
            ))
        .toList(growable: false);
    _cache = List.unmodifiable(bases);
    _deriveRecent(_cache!);
    return _cache!;
  }

  static String _sourceId(Map<String, Object?> record) {
    final value = record['source_id'];
    if (value == null) return defaultSourceId;
    if (value is! String || value.isEmpty) {
      throw const FormatException('Catalogue record has an invalid source_id');
    }
    return value;
  }

  static List<Map<String, Object?>> _decodeBases(String raw) {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed['schemaVersion'] != 1) {
      throw const FormatException('Unsupported catalogue schema');
    }
    final records = parsed['bases'];
    if (records is! List) {
      throw const FormatException('Catalogue asset has no bases list');
    }
    return records
        .map((record) => Map<String, Object?>.from(record as Map))
        .toList(growable: false);
  }

  static void _assertNoDuplicateContent(List<Map<String, Object?>> records) {
    final ids = <String>{};
    final links = <String>{};
    final images = <String>{};
    for (final record in records) {
      final id = record['id'];
      final link = record['link'];
      final image = record['image'];
      if (id is! String || link is! String || image is! String) {
        throw const FormatException('Cleared catalogue record is incomplete');
      }
      if (!ids.add(id)) {
        throw FormatException('Duplicate cleared catalogue ID: $id');
      }
      if (!links.add(link)) {
        throw FormatException('Duplicate cleared catalogue link: $link');
      }
      if (!images.add(image)) {
        throw FormatException('Duplicate cleared catalogue image: $image');
      }
    }
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
    _recent = List.unmodifiable(byNewest.take(3).map((base) => base.id));
  }

  /// True after a successful load when no rights-cleared entries are available.
  @override
  bool get isCatalogueUnavailable => _cache?.isEmpty ?? false;

  @override
  String? get featuredId => null;

  @override
  List<String> get trendingIds => const [];

  @override
  List<String> get recentIds => _recent ?? const [];

  /// Lossless mapper for the upstream `bases.json` schema. Additional taxonomy
  /// is derived only from the explicit table below; all source values remain
  /// available on the resulting [BaseLayout].
  static BaseLayout fromJson(
    Map<String, Object?> json, {
    String sourceId = defaultSourceId,
    CatalogueRightsStatus rightsStatus = CatalogueRightsStatus.unresolved,
  }) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Catalogue record is missing "$key"');
      }
      return value;
    }

    final id = requiredString('id');
    final name = requiredString('name');
    final link = requiredString('link');
    final image = requiredString('image');
    final townHall = json['town_hall'];
    if (townHall is! int) {
      throw const FormatException('Catalogue record has an invalid town_hall');
    }
    final type = json['type'];
    if (type is! String || type.isEmpty) {
      throw const FormatException('Catalogue record is missing "type"');
    }
    final rawTags = json['tags'];
    if (rawTags != null && rawTags is! List) {
      throw const FormatException('Catalogue record has invalid tags');
    }
    final tags = rawTags == null
        ? <String>[]
        : (rawTags as List).map((tag) {
            if (tag is! String) {
              throw const FormatException('Catalogue tag is not a string');
            }
            return tag;
          }).toList(growable: false);
    final builder = json['builder'];
    final description = json['description'];
    final added = json['added'];
    if (builder != null && builder is! String) {
      throw const FormatException('Catalogue builder is not a string');
    }
    if (description != null && description is! String) {
      throw const FormatException('Catalogue description is not a string');
    }
    if (added != null && added is! String) {
      throw const FormatException('Catalogue added value is not a string');
    }
    final builderText = builder is String ? builder : null;
    final descriptionText = description is String ? description : null;
    final addedText = added is String ? added : null;

    final payload = _openLayoutPayload(link);
    final village = switch (payload?.village) {
      'HV' => Village.home,
      'WB' => Village.builder,
      _ => Village.unknown,
    };
    final hallLevel = village == Village.home ? payload?.townHall : null;
    final categories = _categories(type, tags, descriptionText);
    final layoutStyle = _layoutStyle(tags, descriptionText);

    return BaseLayout(
      id: id,
      name: name,
      village: village,
      hallLevel: hallLevel,
      categories: categories,
      layoutStyle: layoutStyle,
      previewSeed: 0,
      imageUrl: image,
      creator: const Creator(name: ''),
      updatedAt: addedText == null ? null : DateTime.tryParse(addedText),
      gameLink: link,
      description: descriptionText,
      sourceId: sourceId,
      sourceCategories: [type],
      sourceTags: tags,
      sourceAttribution: builderText,
      sourceUrl: link,
      sourceTownHall: townHall,
      sourceAdded: addedText,
      addedAt: addedText == null ? null : DateTime.tryParse(addedText),
      rightsStatus: rightsStatus,
      isSample: false,
    );
  }

  static List<String> _categories(
    String type,
    List<String> tags,
    String? description,
  ) {
    final primary = switch (type) {
      'War' => 'War',
      'Farm' => 'Farming',
      'Trophy' => 'Trophy',
      'Hybrid' => 'Hybrid',
      _ => null,
    };
    final result = <String>[if (primary != null) primary];
    final evidence = '${tags.join(' ')} ${description ?? ''}'.toLowerCase();
    const secondary = <String, List<String>>{
      'Anti 2 Star': ['anti-2-star', 'anti 2 star', 'anti-two-star'],
      'Anti 3 Star': ['anti-3-star', 'anti 3 star', 'anti-three-star'],
      'CWL': ['cwl', 'clan war league'],
      'Legend League': ['legend league', 'legend-league'],
      'Ranked': ['ranked'],
    };
    for (final entry in secondary.entries) {
      if (_matchesEvidence(evidence, entry.value) &&
          !result.contains(entry.key)) {
        result.add(entry.key);
      }
    }
    return List.unmodifiable(result);
  }

  static String _layoutStyle(List<String> tags, String? description) {
    final evidence = '${tags.join(' ')} ${description ?? ''}'.toLowerCase();
    const styles = <String, List<String>>{
      'Box': ['box'],
      'Diamond': ['diamond'],
      'Ring': ['ring'],
      'Island': ['island'],
      'Symmetrical': ['symmetrical', 'symmetric'],
      'Asymmetrical': ['asymmetrical', 'asymmetric'],
    };
    for (final entry in styles.entries) {
      if (_matchesEvidence(evidence, entry.value)) return entry.key;
    }
    return '';
  }

  static bool _matchesEvidence(String evidence, List<String> phrases) {
    final normalized = evidence.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    final padded = ' $normalized ';
    for (final phrase in phrases) {
      final candidate =
          phrase.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
      if (candidate.isNotEmpty && padded.contains(' $candidate ')) {
        return true;
      }
    }
    return false;
  }

  static _OpenLayoutPayload? _openLayoutPayload(String link) {
    final id = Uri.tryParse(link)?.queryParameters['id'];
    if (id == null) return null;
    final match = RegExp(r'^TH(\d+):(HV|WB):[A-Za-z0-9_-]{32}$').firstMatch(id);
    if (match == null) return null;
    return _OpenLayoutPayload(
      townHall: int.parse(match.group(1)!),
      village: match.group(2)!,
    );
  }
}

class _OpenLayoutPayload {
  const _OpenLayoutPayload({required this.townHall, required this.village});

  final int townHall;
  final String village;
}
