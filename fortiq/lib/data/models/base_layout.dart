/// Core domain models for Fortiq.
library;

/// Which game village a layout belongs to.
enum Village { home, builder }

extension VillageX on Village {
  String get label => this == Village.home ? 'Home Village' : 'Builder Base';

  /// Hall prefix used across the UI ("TH 16" / "BH 8").
  String get hallPrefix => this == Village.home ? 'TH' : 'BH';

  /// Full hall name ("Town Hall 16" / "Builder Hall 8").
  String get hallName =>
      this == Village.home ? 'Town Hall' : 'Builder Hall';

  /// Highest hall level in the current game.
  int get maxHall => this == Village.home ? 18 : 10;
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
/// are nullable and the UI falls back gracefully when absent.
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
    this.rating,
    this.copies,
    this.updatedLabel,
    this.updatedAt,
    this.verified = false,
    this.gameLink,
    this.description,
  });

  final String id;
  final String name;
  final Village village;
  final int hallLevel;

  /// e.g. ["War", "Anti 3 Star"] — joined with " · " in the UI.
  final List<String> categories;
  final String layoutStyle;
  final int previewSeed;
  final String? imageUrl;
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

  /// True for the bundled design-placeholder dataset, false for real data.
  final bool isSample;

  String get hallBadge => '${village.hallPrefix} $hallLevel';
  String get hallFullName => '${village.hallName} $hallLevel';
  String get categoriesLabel => categories.join(' · ');
  String get creatorHandle => 'by ${creator.name}';
  String get updatedText =>
      updatedLabel ??
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
