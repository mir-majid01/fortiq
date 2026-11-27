/// Core domain models for Fortiq.
library;

import 'catalogue_rights.dart';

/// Which game village a layout belongs to. [unknown] is used when an upstream
/// link does not contain a documented OpenLayout village marker.
enum Village { home, builder, unknown }

extension VillageX on Village {
  String get label => switch (this) {
        Village.home => 'Home Village',
        Village.builder => 'Builder Base',
        Village.unknown => 'Unknown village',
      };

  /// Hall prefix used across the UI ("TH 16" / "BH 8").
  String get hallPrefix => switch (this) {
        Village.home => 'TH',
        Village.builder => 'BH',
        Village.unknown => '',
      };

  /// Full hall name ("Town Hall 16" / "Builder Hall 8").
  String get hallName => switch (this) {
        Village.home => 'Town Hall',
        Village.builder => 'Builder Hall',
        Village.unknown => 'Hall',
      };

  /// Highest hall level in the current game.
  int get maxHall => switch (this) {
        Village.home => 18,
        Village.builder => 10,
        Village.unknown => 0,
      };
}

/// A base-layout creator.
class Creator {
  const Creator({required this.name, this.verified = false});

  final String name;
  final bool verified;

  String get initial =>
      name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
}

/// A Clash of Clans base layout.
///
/// `rating`, `copies` and `verified` come from curation. The community
/// catalogue provides real layout data but no live statistics, so those fields
/// stay absent unless a future source supplies evidence.
class BaseLayout {
  const BaseLayout({
    required this.id,
    required this.name,
    required this.village,
    required this.hallLevel,
    required this.categories,
    required this.layoutStyle,
    required this.previewSeed,
    required this.creator,
    required this.isSample,
    this.imageUrl,
    this.localImagePath,
    this.rating,
    this.copies,
    this.updatedLabel,
    this.updatedAt,
    this.verified = false,
    this.gameLink,
    this.description,
    this.sourceId,
    this.sourceCategories = const [],
    this.sourceTags = const [],
    this.sourceAttribution,
    this.sourceUrl,
    this.sourceTownHall,
    this.sourceAdded,
    this.addedAt,
    this.rightsStatus = CatalogueRightsStatus.unresolved,
  });

  final String id;
  final String name;
  final Village village;

  /// Null when the source does not document a hall level for [village]. In
  /// particular, an OpenLayout `WB` payload never supplies a Builder Hall level.
  final int? hallLevel;

  /// Explicitly mapped Fortiq categories; empty means unclassified.
  final List<String> categories;

  /// Empty for upstream records unless a source explicitly classifies style.
  final String layoutStyle;
  final int previewSeed;
  final String? imageUrl;
  final String? localImagePath;
  final Creator creator;

  final double? rating;
  final int? copies;

  /// Curated recency string ("New · 2h ago", "Updated 2d ago").
  final String? updatedLabel;
  final DateTime? updatedAt;
  final bool verified;

  /// Official `link.clashofclans.com` deep link, when one exists.
  final String? gameLink;
  final String? description;

  /// Lossless upstream metadata. The upstream schema has no separate source
  /// page URL, so [sourceUrl] preserves its record URL exactly.
  final String? sourceId;
  final List<String> sourceCategories;
  final List<String> sourceTags;
  final String? sourceAttribution;
  final String? sourceUrl;
  final int? sourceTownHall;
  final String? sourceAdded;
  final DateTime? addedAt;
  final CatalogueRightsStatus rightsStatus;

  /// True for the bundled design-placeholder dataset, false for real data.
  final bool isSample;

  String get hallBadge =>
      hallLevel == null ? village.label : '${village.hallPrefix} $hallLevel';
  String get hallFullName =>
      hallLevel == null ? village.hallName : '${village.hallName} $hallLevel';
  String get categoriesLabel =>
      categories.isEmpty ? 'Unclassified' : categories.join(' · ');
  String get creatorHandle {
    final attribution = sourceAttribution?.trim();
    if (attribution != null && attribution.isNotEmpty) {
      return 'Source: $attribution';
    }
    final name = creator.name.trim();
    return name.isEmpty ? 'Source unavailable' : 'by $name';
  }

  String get updatedText => addedAt != null
      ? 'Added ${_relative(addedAt!)}'
      : updatedLabel ??
          (updatedAt != null ? 'Updated ${_relative(updatedAt!)}' : '—');

  static String _relative(DateTime then) {
    final days = DateTime.now().difference(then).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return '1d ago';
    if (days < 30) return '${days}d ago';
    return 'over a month ago';
  }

  String copiesLabel() {
    final c = copies;
    if (c == null) return '—';
    if (c >= 1000) {
      final k = c / 1000;
      return '${k.toStringAsFixed(1)}k copies';
    }
    return '$c copies';
  }
}
