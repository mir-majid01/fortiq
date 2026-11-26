import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'svg_path.dart';

/// The Fortiq emblem — the three-path shield crest from the reference
/// screens (viewBox 0 0 100 128), drawn as vectors.
class FortiqEmblem extends StatelessWidget {
  const FortiqEmblem({super.key, this.width = 92, this.height = 118});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _EmblemPainter()),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  // Path data copied verbatim from the reference markup.
  static final Path _crestTop = parseSvgPath(
    'M21.05 24.5V9H31.55V14.5H36.85V3.5H47.35V14.5H52.65V3.5H63.15V14.5H68.45V9H78.95V24.5Z',
  );
  static final Path _shield = parseSvgPath(
    'M5 30H95V93L50 124.5L5 93ZM15.75 40.5H84.25V87.4L50 111.4L15.75 87.4Z',
    fillType: PathFillType.evenOdd,
  );
  static final Path _innerCrest = parseSvgPath(
    'M21.05 45.8H78.95V84.65L68.45 92V56.5H63.15V95.72L50 104.93L36.85 95.72V56.5H31.55V92L21.05 84.65Z',
  );

  @override
  void paint(Canvas canvas, Size size) {
    // preserveAspectRatio xMidYMid meet against the 100×128 viewBox.
    final scale = math.min(size.width / 100, size.height / 128);
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 128 * scale) / 2,
    );
    canvas.scale(scale);

    final bright = Paint()..color = AppColors.goldBright;
    final gold = Paint()..color = AppColors.gold;
    canvas.drawPath(_crestTop, bright);
    canvas.drawPath(_shield, gold);
    canvas.drawPath(_innerCrest, bright);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) => false;
}
