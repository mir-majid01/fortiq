import '../models/base_layout.dart';

class OpenLayoutLink {
  const OpenLayoutLink({
    required this.originalUrl,
    required this.village,
    required this.hallLevel,
  });

  final String originalUrl;
  final Village village;
  final int? hallLevel;

  static OpenLayoutLink parse(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'link.clashofclans.com' ||
        uri.queryParameters['action'] != 'OpenLayout') {
      throw const FormatException('Use an official HTTPS OpenLayout link.');
    }
    final id = uri.queryParameters['id'];
    final match = id == null
        ? null
        : RegExp(r'^TH(\d+):(HV|WB|BB2|BB):[A-Za-z0-9_-]{32}$')
            .firstMatch(id);
    if (match == null) {
      throw const FormatException('The OpenLayout payload is invalid.');
    }
    // `HV` is a normal home-village layout, `WB` is a home-village war base,
    // and `BB`/`BB2` are Builder Base layouts whose number is the Builder
    // Hall level.
    final village = switch (match.group(2)) {
      'HV' || 'WB' => Village.home,
      _ => Village.builder,
    };
    return OpenLayoutLink(
      originalUrl: value,
      village: village,
      hallLevel: int.parse(match.group(1)!),
    );
  }
}
