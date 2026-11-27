import 'package:flutter/material.dart';

import 'svg_path.dart';

/// The exact stroke-icon paths used by the approved design (24×24 viewBox,
/// 1.75 stroke, round caps/joins). Rendered through [FortiqIcon].
abstract final class FortiqIcons {
  static const List<String> bell = [
    'M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8',
    'M10.3 20a1.9 1.9 0 0 0 3.4 0',
  ];
  static const List<String> heart = [
    'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.6-7 10-7 10z',
  ];
  static const List<String> search = [
    'M11 4a7 7 0 1 0 0 14a7 7 0 1 0 0-14z',
    'M20 20l-3.5-3.5',
  ];
  static const List<String> chevronDown = ['M6 9l6 6 6-6'];
  static const List<String> chevronLeft = ['M15 5l-7 7 7 7'];
  static const List<String> sliders = ['M4 6h16M7 12h10M10 18h4'];
  static const List<String> external = [
    'M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5',
  ];
  static const List<String> share = [
    'M12 15V4M8 8l4-4 4 4M5 13v6a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-6',
  ];
  static const List<String> copy = [
    'M11 9h7a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-7a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z',
    'M5 15V6a2 2 0 0 1 2-2h9',
  ];
  static const List<String> expand = ['M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5'];
  static const List<String> shieldCheck = [
    'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',
    'M8.5 12l2.5 2.5 4.5-5',
  ];
  static const List<String> check = ['M5 12l5 5L20 7'];
  static const List<String> close = ['M6 6l12 12M18 6L6 18'];
  static const List<String> plus = ['M12 5v14M5 12h14'];
  static const List<String> update = [
    'M20 11a8 8 0 1 0-2.3 5.7',
    'M20 4v7h-7',
  ];

  /// Star — reference renders it filled (no stroke).
  static const List<String> starFilled = [
    'M12 3l2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.2 6.5 20.2l1-6.2L3 9.6l6.2-.9z',
  ];
  // Bottom navigation (single compound paths, as in the reference).
  static const List<String> navHome = [
    'M3 10.5L12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
  ];
  static const List<String> navExplore = [
    'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM15.5 8.5l-2 5-5 2 2-5z',
  ];
  static const List<String> navCollections = [
    'M4 6a2 2 0 0 1 2-2h4l2 2h6a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z',
  ];
  // Home category icons.
  static const List<String> war = ['M5 19L19 5M14 5h5v5M5 5l14 14'];
  static const List<String> trophy = [
    'M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0zM17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3',
  ];
  static const List<String> farming = [
    'M12 22V12M12 12c0-4 3-6 7-6 0 4-3 6-7 6zM12 14c0-3-2-5-6-5 0 3 2 5 6 5z',
  ];
  static const List<String> hybrid = ['M12 3l9 5-9 5-9-5zM3 13l9 5 9-5'];
  static const List<String> legend = ['M3 8l4 4 5-7 5 7 4-4-2 11H5z'];
  static const List<String> cwl = [
    'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',
  ];
}

/// Renders a reference icon as vector strokes/fills identical to the SVG.
class FortiqIcon extends StatelessWidget {
  const FortiqIcon(
    this.paths, {
    super.key,
    required this.size,
    this.color,
    this.strokeWidth = 1.75,
    this.filled = false,
  });

  final List<String> paths;
  final double size;
  final Color? color;
  final double strokeWidth;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IconPainter(
          paths: paths,
          color: color ?? const Color(0xFFF2F4F7),
          strokeWidth: strokeWidth,
          filled: filled,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({
    required this.paths,
    required this.color,
    required this.strokeWidth,
    required this.filled,
  });

  final List<String> paths;
  final Color color;
  final double strokeWidth;
  final bool filled;

  static final Map<String, List<Path>> _cache = {};

  List<Path> _build() {
    final key = paths.join('|');
    return _cache.putIfAbsent(key, () {
      return paths.map((d) => parseSvgPath(d)).toList(growable: false);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    if (filled) {
      final fill = Paint()..color = color;
      for (final p in _build()) {
        canvas.drawPath(p, fill);
      }
    } else {
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final p in _build()) {
        canvas.drawPath(p, stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.filled != filled ||
      old.paths != paths;
}
