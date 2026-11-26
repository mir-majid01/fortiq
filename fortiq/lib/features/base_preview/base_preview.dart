import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Reusable base-preview illustration.
///
/// A faithful Dart port of the approved reference component: a deterministic,
/// seed-driven isometric base scene (grass slab, three wall rings, buildings,
/// trees, radial backdrop and vignette) rendered on a `CustomPainter`.
///
/// The generator is bit-compatible with the reference JavaScript — the same
/// seed always yields the same scene, so `seed: 3` matches `BasePreview
/// seed=3` in the design. Geometry is computed once per seed and cached.
///
/// The widget fills its parent; wrap in `ClipRRect` for rounded corners.
/// When real base screenshots become available this widget can delegate to an
/// `Image` without touching any call sites.
class BasePreview extends StatelessWidget {
  const BasePreview({super.key, required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BasePreviewPainter(seed: seed),
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Deterministic generator (port of the reference script)
// ---------------------------------------------------------------------------

class _Lcg {
  _Lcg(int seed) : _st = (seed * 7919 + 12345) % 233280;

  int _st;

  double next() {
    _st = (_st * 9301 + 49297) % 233280;
    return _st / 233280;
  }
}

class PreviewTree {
  PreviewTree(this.x, this.y, this.sy, this.r, this.hx, this.hy, this.hr);

  final double x, y, sy, r, hx, hy, hr;
}

class PreviewBuilding {
  PreviewBuilding(this.depth, this.index, this.top, this.left, this.right, this.c0,
      this.c1, this.c2);

  final double depth;
  final int index;
  final List<double> top, left, right;
  final Color c0, c1, c2;
}

class PreviewWallRing {
  PreviewWallRing(this.shadow, this.mid, this.light);

  final List<double> shadow, mid, light;
}

class PreviewTheme {
  const PreviewTheme(this.g1, this.g2, this.tree, this.top, this.slabTop, this.s1,
      this.s2);

  final Color g1, g2, tree, top, slabTop, s1, s2;
}

class PreviewPalette {
  const PreviewPalette(this.c0, this.c1, this.c2);

  final Color c0, c1, c2;
}

const List<PreviewTheme> _themes = [
  PreviewTheme(
      Color(0xFF46663A), Color(0xFF273B20), Color(0xFF2C4A25), Color(0xFF5F8A3F),
      Color(0xFF8A7650), Color(0xFF6B5A3A), Color(0xFF4D4029)),
  PreviewTheme(
      Color(0xFF6A5D40), Color(0xFF352D1F), Color(0xFF4D5A30), Color(0xFF7D7048),
      Color(0xFFA48E60), Color(0xFF7A6644), Color(0xFF574830)),
  PreviewTheme(
      Color(0xFF8FA2B2), Color(0xFF4F6070), Color(0xFF4A6A55), Color(0xFFC6D3DE),
      Color(0xFF9FB0BE), Color(0xFF7F93A4), Color(0xFF5D7080)),
  PreviewTheme(
      Color(0xFF35493F), Color(0xFF17231E), Color(0xFF223A2D), Color(0xFF47664F),
      Color(0xFF6D6A52), Color(0xFF554F3C), Color(0xFF3B372A)),
];

const List<PreviewPalette> _palettes = [
  PreviewPalette(Color(0xFFB4C0D0), Color(0xFF8693A6), Color(0xFF667385)),
  PreviewPalette(Color(0xFFB4C0D0), Color(0xFF8693A6), Color(0xFF667385)),
  PreviewPalette(Color(0xFFDAB468), Color(0xFFAD8744), Color(0xFF86642F)),
  PreviewPalette(Color(0xFF9DB088), Color(0xFF74875F), Color(0xFF586A47)),
  PreviewPalette(Color(0xFFCF7A68), Color(0xFFA15548), Color(0xFF7D4036)),
  PreviewPalette(Color(0xFFC2BAA8), Color(0xFF908A7A), Color(0xFF6F6A5E)),
];

// Stroke/overlay colours from the reference SVG.
const Color _wallShadow = Color(0x8C141008); // rgba(20,16,8,.55)
const Color _wallMid = Color(0xFFA89F84);
const Color _wallLight = Color(0xFFE8E1C9);
const Color _buildingEdge = Color(0x40FFFFFF); // rgba(255,255,255,.25)
const Color _treeShadow = Color(0x47000000); // rgba(0,0,0,.28)
const Color _treeHighlight = Color(0x1FFFFFFF); // rgba(255,255,255,.12)
const Color _vignetteEdge = Color(0x61000000); // rgba(0,0,0,.38)

class PreviewGeometry {
  PreviewGeometry._({
    required this.theme,
    required this.trees,
    required this.walls,
    required this.buildings,
    required this.slabLeft,
    required this.slabRight,
    required this.slabTop,
    required this.grass,
  });

  final PreviewTheme theme;
  final List<PreviewTree> trees;
  final List<PreviewWallRing> walls;
  final List<PreviewBuilding> buildings;
  final List<double> slabLeft, slabRight, slabTop, grass;

  static final Map<int, PreviewGeometry> _cache = {};

  static PreviewGeometry forSeed(int seed) {
    return _cache.putIfAbsent(seed, () => _generate(seed));
  }

  // Isometric projection, exactly as in the reference:
  // P(x, y, z) = [50 + (x - y) * k, oy + (x + y) * k * 0.5 - z]
  static (double, double) _proj(double x, double y, [double z = 0]) {
    const k = 0.66;
    const oy = 53.0;
    return (50 + (x - y) * k, oy + (x + y) * k * 0.5 - z);
  }

  /// Reference rounds every coordinate to one decimal (`toFixed(1)`).
  static double _r1(double v) => (v * 10).roundToDouble() / 10;

  static List<double> _poly(Iterable<(double, double)> points) =>
      points.expand((p) => <double>[_r1(p.$1), _r1(p.$2)]).toList();

  static PreviewGeometry _generate(int seed) {
    final rnd = _Lcg(seed);
    final theme = _themes[seed % 4];

    (double, List<double>, List<double>, List<double>, PreviewPalette) box(
        double gx, double gy, double s, double h, PreviewPalette c) {
      // Corner 0 (gx, gy) is never referenced by the reference faces either.
      final b1 = _proj(gx + s, gy);
      final b2 = _proj(gx + s, gy + s);
      final b3 = _proj(gx, gy + s);
      final t0 = _proj(gx, gy, h);
      final t1 = _proj(gx + s, gy, h);
      final t2 = _proj(gx + s, gy + s, h);
      final t3 = _proj(gx, gy + s, h);
      return (
        gx + gy + s,
        _poly([t0, t1, t2, t3]),
        _poly([b3, b2, t2, t3]),
        _poly([b1, b2, t2, t1]),
        c,
      );
    }

    final buildings = <(double, int, List<double>, List<double>, List<double>,
        PreviewPalette)>[];
    var index = 0;
    for (var i = -3; i <= 3; i++) {
      for (var j = -3; j <= 3; j++) {
        if (i == 0 && j == 0) continue;
        if (rnd.next() < 0.3) continue;
        final s = 4.2 + rnd.next() * 2.6;
        final gx = i * 9 - s / 2 + (rnd.next() - 0.5) * 1.6;
        final gy = j * 9 - s / 2 + (rnd.next() - 0.5) * 1.6;
        final h = 2 + rnd.next() * 3.2;
        final b = box(gx, gy, s, h, _palettes[(rnd.next() * _palettes.length).floor()]);
        buildings.add((b.$1, index++, b.$2, b.$3, b.$4, b.$5));
      }
    }
    // Central keep (gold palette), added after the loop like the reference.
    final central =
        box(-4.5, -4.5, 9, 6.5, _palettes[2]);
    buildings.add((central.$1, index++, central.$2, central.$3, central.$4,
        central.$5));

    // Reference Array#sort is stable — tie-break on insertion index.
    buildings.sort((a, b) {
      final byDepth = a.$1.compareTo(b.$1);
      return byDepth != 0 ? byDepth : a.$2.compareTo(b.$2);
    });

    // Wall rings.
    List<double> ring(double a, double z) => _poly([
          _proj(-a, -a, z),
          _proj(a, -a, z),
          _proj(a, a, z),
          _proj(-a, a, z),
          _proj(-a, -a, z),
        ]);
    final walls = <PreviewWallRing>[];
    for (final a in const [13.5, 22.5, 31.5]) {
      walls.add(PreviewWallRing(ring(a, 0), ring(a, 0.8), ring(a, 1.6)));
    }

    // Slab + grass.
    (double, double) drop((double, double) p, double d) => (p.$1, p.$2 + d);
    final slab = [
      _proj(-38, -38),
      _proj(38, -38),
      _proj(38, 38),
      _proj(-38, 38),
    ];
    final slabLeft = _poly(
        [slab[3], slab[2], drop(slab[2], 3), drop(slab[3], 3)]);
    final slabRight = _poly(
        [slab[1], slab[2], drop(slab[2], 3), drop(slab[1], 3)]);
    final slabTop = _poly(slab);
    final grass = _poly([
      _proj(-36, -36),
      _proj(36, -36),
      _proj(36, 36),
      _proj(-36, 36),
    ]);

    // Trees — up to 16, outside the base diamond.
    final trees = <PreviewTree>[];
    for (var n = 0; n < 40 && trees.length < 16; n++) {
      final x = rnd.next() * 100;
      final y = rnd.next() * 100;
      if ((x - 50).abs() / 47 + (y - 53).abs() / 25 < 1.2) continue;
      final r = 1.8 + rnd.next() * 2.2;
      trees.add(PreviewTree(
        _r1(x),
        _r1(y),
        _r1(y + r * 0.6),
        _r1(r),
        _r1(x - r * 0.3),
        _r1(y - r * 0.3),
        _r1(r * 0.45),
      ));
    }

    return PreviewGeometry._(
      theme: theme,
      trees: trees,
      walls: walls,
      buildings: [
        for (final b in buildings)
          PreviewBuilding(b.$1, b.$2, b.$3, b.$4, b.$5, b.$6.c0, b.$6.c1, b.$6.c2),
      ],
      slabLeft: slabLeft,
      slabRight: slabRight,
      slabTop: slabTop,
      grass: grass,
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _BasePreviewPainter extends CustomPainter {
  _BasePreviewPainter({required this.seed});

  final int seed;

  static Path _pathFrom(List<double> pts) {
    final path = Path();
    path.moveTo(pts[0], pts[1]);
    for (var i = 2; i < pts.length; i += 2) {
      path.lineTo(pts[i], pts[i + 1]);
    }
    path.close();
    return path;
  }

  static Path _lineFrom(List<double> pts) {
    final path = Path();
    path.moveTo(pts[0], pts[1]);
    for (var i = 2; i < pts.length; i += 2) {
      path.lineTo(pts[i], pts[i + 1]);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geo = PreviewGeometry.forSeed(seed);
    final t = geo.theme;

    // Base fill (matches the component background).
    canvas.drawRect(Offset.zero & size, Paint()..color = t.g2);

    // preserveAspectRatio="xMidYMid slice": scale the 100×100 viewBox to
    // cover the widget, centred.
    final sliceScale = math.max(size.width, size.height) / 100;
    final ox = (size.width - 100 * sliceScale) / 2;
    final oy = (size.height - 100 * sliceScale) / 2;
    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(sliceScale);

    // Backdrop radial gradient (cx 50% cy 52% r 75%).
    final backdrop = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(50, 52),
        75,
        [t.g1, t.g2],
        const [0.0, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), backdrop);

    // Trees (shadow → body → highlight).
    for (final tr in geo.trees) {
      canvas.drawCircle(Offset(tr.x, tr.sy), tr.r, Paint()..color = _treeShadow);
      canvas.drawCircle(Offset(tr.x, tr.y), tr.r, Paint()..color = t.tree);
      canvas.drawCircle(
          Offset(tr.hx, tr.hy), tr.hr, Paint()..color = _treeHighlight);
    }

    // Slab sides, top and grass.
    canvas.drawPath(_pathFrom(geo.slabLeft), Paint()..color = t.s1);
    canvas.drawPath(_pathFrom(geo.slabRight), Paint()..color = t.s2);
    canvas.drawPath(_pathFrom(geo.slabTop), Paint()..color = t.slabTop);
    canvas.drawPath(_pathFrom(geo.grass), Paint()..color = t.top);

    // Wall rings: dark shadow, mid and light strokes.
    for (final ring in geo.walls) {
      final shadow = Paint()
        ..color = _wallShadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round;
      final mid = Paint()
        ..color = _wallMid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round;
      final light = Paint()
        ..color = _wallLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(_lineFrom(ring.shadow), shadow);
      canvas.drawPath(_lineFrom(ring.mid), mid);
      canvas.drawPath(_lineFrom(ring.light), light);
    }

    // Buildings, painted far → near.
    for (final b in geo.buildings) {
      canvas.drawPath(_pathFrom(b.left), Paint()..color = b.c1);
      canvas.drawPath(_pathFrom(b.right), Paint()..color = b.c2);
      // Top face: palette fill with a faint light edge stroke.
      canvas.drawPath(_pathFrom(b.top), Paint()..color = b.c0);
      canvas.drawPath(
        _pathFrom(b.top),
        Paint()
          ..color = _buildingEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.2,
      );
    }

    canvas.restore();

    // Vignette overlay — drawn in widget space (ellipse at centre).
    final cx = size.width / 2, cy = size.height / 2;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1, size.height / size.width);
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        cx,
        const [
          Color(0x00000000),
          Color(0x00000000),
          _vignetteEdge,
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size.width, height: size.width), vignette);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BasePreviewPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
