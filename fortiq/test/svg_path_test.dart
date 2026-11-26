import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/core/icons/svg_path.dart';

void main() {
  test('parses straight-line emblem paths with correct bounds', () {
    final p = parseSvgPath('M5 30H95V93L50 124.5L5 93Z');
    expect(p.getBounds(), const Rect.fromLTRB(5, 30, 95, 124.5));
  });

  test('relative commands accumulate', () {
    final p = parseSvgPath('M10 10l5 5h-10z');
    expect(p.getBounds(), const Rect.fromLTRB(5, 10, 15, 15));
  });

  test('arc command produces a closed circle', () {
    final p = parseSvgPath('M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14z');
    final b = p.getBounds();
    // Circle centre (11,11) radius 7 — allow bézier-approximation slack.
    expect(b.left, closeTo(4, 0.2));
    expect(b.right, closeTo(18, 0.2));
    expect(b.top, closeTo(4, 0.2));
    expect(b.bottom, closeTo(18, 0.2));
  });

  test('cubic bell path parses without throwing', () {
    final p = parseSvgPath('M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8');
    expect(p.getBounds().height, greaterThan(10));
  });

  test('implicit lineto after moveto', () {
    final p = parseSvgPath('M0 0 10 0 10 10z');
    expect(p.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
  });
}
