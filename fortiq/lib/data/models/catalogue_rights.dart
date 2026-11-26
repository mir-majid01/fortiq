/// Rights state for catalogue content. Unknown or missing evidence always
/// resolves to [unresolved]; only an explicit grant may become [cleared].
enum CatalogueRightsStatus {
  cleared,
  unresolved,
  denied,
  sample;

  String get wireValue => name;

  static CatalogueRightsStatus fromJson(Object? value) {
    if (value == null) return unresolved;
    return switch (value) {
      'cleared' => cleared,
      'unresolved' => unresolved,
      'denied' => denied,
      'sample' => sample,
      _ => throw FormatException('Unknown catalogue rights status: $value'),
    };
  }
}

/// Permission evidence for one upstream catalogue source.
class CatalogueSourceRights {
  const CatalogueSourceRights({
    required this.id,
    required this.name,
    required this.upstreamUrl,
    required this.license,
    required this.licenseNotice,
    required this.contentRedistribution,
    required this.previewRedistribution,
    required this.evidence,
  });

  final String id;
  final String name;
  final String upstreamUrl;
  final String license;
  final String licenseNotice;
  final CatalogueRightsStatus contentRedistribution;
  final CatalogueRightsStatus previewRedistribution;
  final String evidence;

  /// Fortiq only publishes a source when both its records and previews are
  /// explicitly cleared. A software licence alone is not content permission.
  bool get isCleared =>
      contentRedistribution == CatalogueRightsStatus.cleared &&
      previewRedistribution == CatalogueRightsStatus.cleared;

  factory CatalogueSourceRights.fromJson(Map<String, Object?> json) {
    String required(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Catalogue source is missing "$key"');
      }
      return value;
    }

    return CatalogueSourceRights(
      id: required('id'),
      name: required('name'),
      upstreamUrl: required('upstreamUrl'),
      license: required('license'),
      licenseNotice: required('licenseNotice'),
      contentRedistribution:
          CatalogueRightsStatus.fromJson(json['contentRedistribution']),
      previewRedistribution:
          CatalogueRightsStatus.fromJson(json['previewRedistribution']),
      evidence: required('evidence'),
    );
  }
}

/// Packaged, per-source rights evidence. Parsing is fail-closed: malformed
/// manifests prevent catalogue publication instead of silently allowing data.
class CatalogueRightsManifest {
  const CatalogueRightsManifest({
    required this.schemaVersion,
    required this.sources,
    required this.unofficialDisclosure,
  });

  final int schemaVersion;
  final List<CatalogueSourceRights> sources;
  final String unofficialDisclosure;

  Iterable<CatalogueSourceRights> get clearedSources =>
      sources.where((source) => source.isCleared);

  CatalogueSourceRights? sourceById(String id) {
    for (final source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  factory CatalogueRightsManifest.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    final rawSources = json['sources'];
    final disclosure = json['unofficialDisclosure'];
    if (version is! int || version != 1) {
      throw const FormatException('Unsupported catalogue rights schema');
    }
    if (rawSources is! List) {
      throw const FormatException('Catalogue rights manifest has no sources');
    }
    if (disclosure is! String || disclosure.isEmpty) {
      throw const FormatException('Catalogue rights disclosure is missing');
    }

    final sources = rawSources.map((source) {
      if (source is! Map) {
        throw const FormatException('Invalid catalogue source rights entry');
      }
      return CatalogueSourceRights.fromJson(Map<String, Object?>.from(source));
    }).toList(growable: false);
    final ids = sources.map((source) => source.id).toSet();
    if (ids.length != sources.length) {
      throw const FormatException('Duplicate catalogue source rights IDs');
    }

    return CatalogueRightsManifest(
      schemaVersion: version,
      sources: sources,
      unofficialDisclosure: disclosure,
    );
  }
}
