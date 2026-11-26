import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/features/base_preview/base_preview.dart';

/// The Dart port of the reference generator must produce exactly the same
/// scene per seed as the JavaScript (verified against a Python replica of
/// the original script).
void main() {
  test('building/tree counts match the reference per seed', () {
    // (seed, themeIndex, buildings, trees) — from the JS replica.
    const expected = {
      3: (3, 31, 16),
      5: (1, 33, 16),
      6: (2, 36, 16),
      8: (0, 40, 16),
      11: (3, 35, 16),
      12: (0, 34, 16),
      14: (2, 31, 16),
      15: (3, 37, 16),
      17: (1, 35, 16),
      20: (0, 33, 16),
    };
    for (final entry in expected.entries) {
      final geo = PreviewGeometry.forSeed(entry.key);
      expect(geo.buildings.length, entry.value.$2,
          reason: 'seed ${entry.key} buildings');
      expect(geo.trees.length, entry.value.$3,
          reason: 'seed ${entry.key} trees');
    }
  });

  test('same seed is deterministic and cached', () {
    final a = PreviewGeometry.forSeed(3);
    final b = PreviewGeometry.forSeed(3);
    expect(identical(a, b), isTrue);
  });

  test('seed selects the theme cyclically', () {
    expect(PreviewGeometry.forSeed(3).theme.g1,
        PreviewGeometry.forSeed(7).theme.g1); // both 3 % 4
    expect(PreviewGeometry.forSeed(8).theme.g1,
        isNot(PreviewGeometry.forSeed(3).theme.g1));
  });

  test('walls always come in three rings', () {
    expect(PreviewGeometry.forSeed(42).walls.length, 3);
  });
}
