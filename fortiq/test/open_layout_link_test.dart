import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/sources/open_layout_link.dart';

void main() {
  test('parses documented Home and Builder OpenLayout payloads', () {
    final home = OpenLayoutLink.parse(
      'https://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA',
    );
    expect(home.village, Village.home);
    expect(home.hallLevel, 17);
    expect(home.originalUrl, contains('TH17%3AHV%3A'));

    final builder = OpenLayoutLink.parse(
      'https://link.clashofclans.com/fi?action=OpenLayout&id=TH12%3AWB%3AAAAAHgAAAAFy_S4-CzVCnBGBJfbJGxmp',
    );
    expect(builder.village, Village.builder);
    expect(builder.hallLevel, isNull);
  });

  test('rejects unofficial hosts malformed actions and undocumented payloads',
      () {
    const invalid = [
      'http://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA',
      'https://example.com/en?action=OpenLayout&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA',
      'https://link.clashofclans.com/en?action=Other&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA',
      'https://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AXX%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA',
      'https://link.clashofclans.com/en?action=OpenLayout&id=short',
    ];
    for (final url in invalid) {
      expect(() => OpenLayoutLink.parse(url), throwsFormatException);
    }
  });
}
