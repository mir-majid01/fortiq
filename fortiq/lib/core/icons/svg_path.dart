import 'dart:math' as math;
import 'dart:ui' show Path, PathFillType;

/// Minimal SVG `d` attribute parser covering the command subset used by the
/// approved design: M m L l H h V v C c S s Q q T t A a Z z.
///
/// The reference screens draw their icons and the Fortiq emblem as plain SVG
/// paths; this keeps them vector-perfect in Flutter without an SVG dependency.
Path parseSvgPath(String d, {PathFillType fillType = PathFillType.nonZero}) {
  final p = _Parser(d);
  return p.parse()..fillType = fillType;
}

class _Parser {
  _Parser(this._d);

  final String _d;
  int _i = 0;

  double _x = 0, _y = 0; // current point
  double _startX = 0, _startY = 0; // subpath start
  double? _c1x, _c1y; // last cubic control (S/s reflection)
  double? _q1x, _q1y; // last quad control (T/t reflection)
  String? _prevCmd;
  final Path _path = Path();

  Path parse() {
    while (_i < _d.length) {
      _skipSeparators();
      if (_i >= _d.length) break;

      final c = _d[_i];
      final isLetter = _isCommandChar(c);
      String cmd;
      if (isLetter) {
        _i++;
        cmd = c;
      } else {
        // Implicit repeat: M continues as L, m as l.
        final prev = _prevCmd;
        if (prev == null) break;
        cmd = prev == 'M' ? 'L' : prev == 'm' ? 'l' : prev;
      }
      _prevCmd = cmd;

      switch (cmd) {
        case 'M':
        case 'm':
          _move(cmd == 'm');
          break;
        case 'L':
        case 'l':
          _line(cmd == 'l');
          break;
        case 'H':
        case 'h':
          _h(cmd == 'h');
          break;
        case 'V':
        case 'v':
          _v(cmd == 'v');
          break;
        case 'C':
        case 'c':
          _cubic(cmd == 'c');
          break;
        case 'S':
        case 's':
          _smoothCubic(cmd == 's');
          break;
        case 'Q':
        case 'q':
          _quad(cmd == 'q');
          break;
        case 'T':
        case 't':
          _smoothQuad(cmd == 't');
          break;
        case 'A':
        case 'a':
          _arc(cmd == 'a');
          break;
        case 'Z':
        case 'z':
          _path.close();
          _x = _startX;
          _y = _startY;
          _c1x = _c1y = _q1x = _q1y = null;
          break;
        default:
          _i++; // unknown command — skip it
      }
    }
    return _path;
  }

  bool _isCommandChar(String c) => 'MmLlHhVvCcSsQqTtAaZz'.contains(c);

  void _skipSeparators() {
    while (_i < _d.length) {
      final c = _d[_i];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        _i++;
      } else {
        break;
      }
    }
  }

  double _num() {
    _skipSeparators();
    final start = _i;
    if (_i < _d.length && (_d[_i] == '+' || _d[_i] == '-')) _i++;
    while (_i < _d.length && _isDigit(_d[_i])) {
      _i++;
    }
    if (_i < _d.length && _d[_i] == '.') {
      _i++;
      while (_i < _d.length && _isDigit(_d[_i])) {
        _i++;
      }
    }
    if (_i < _d.length && (_d[_i] == 'e' || _d[_i] == 'E')) {
      final e = _i;
      _i++;
      if (_i < _d.length && (_d[_i] == '+' || _d[_i] == '-')) _i++;
      if (_i < _d.length && _isDigit(_d[_i])) {
        while (_i < _d.length && _isDigit(_d[_i])) {
          _i++;
        }
      } else {
        _i = e; // not an exponent after all
      }
    }
    return double.parse(_d.substring(start, _i));
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  int _flag() => _num() != 0 ? 1 : 0;

  void _move(bool rel) {
    final x = _num(), y = _num();
    _c1x = _c1y = _q1x = _q1y = null;
    if (rel) {
      _x += x;
      _y += y;
    } else {
      _x = x;
      _y = y;
    }
    _startX = _x;
    _startY = _y;
    _path.moveTo(_x, _y);
  }

  void _line(bool rel) {
    final x = _num(), y = _num();
    _x = rel ? _x + x : x;
    _y = rel ? _y + y : y;
    _path.lineTo(_x, _y);
  }

  void _h(bool rel) {
    final x = _num();
    _x = rel ? _x + x : x;
    _path.lineTo(_x, _y);
  }

  void _v(bool rel) {
    final y = _num();
    _y = rel ? _y + y : y;
    _path.lineTo(_x, _y);
  }

  void _cubic(bool rel) {
    final x1 = _num(), y1 = _num();
    final x2 = _num(), y2 = _num();
    final x = _num(), y = _num();
    if (rel) {
      _path.cubicTo(_x + x1, _y + y1, _x + x2, _y + y2, _x + x, _y + y);
      _c1x = _x + x2;
      _c1y = _y + y2;
      _x += x;
      _y += y;
    } else {
      _path.cubicTo(x1, y1, x2, y2, x, y);
      _c1x = x2;
      _c1y = y2;
      _x = x;
      _y = y;
    }
  }

  void _smoothCubic(bool rel) {
    final x2 = _num(), y2 = _num();
    final x = _num(), y = _num();
    double cx, cy;
    if (_c1x != null) {
      cx = 2 * _x - _c1x!;
      cy = 2 * _y - _c1y!;
    } else {
      cx = _x;
      cy = _y;
    }
    if (rel) {
      _path.cubicTo(cx, cy, _x + x2, _y + y2, _x + x, _y + y);
      _c1x = _x + x2;
      _c1y = _y + y2;
      _x += x;
      _y += y;
    } else {
      _path.cubicTo(cx, cy, x2, y2, x, y);
      _c1x = x2;
      _c1y = y2;
      _x = x;
      _y = y;
    }
  }

  void _quad(bool rel) {
    final x1 = _num(), y1 = _num();
    final x = _num(), y = _num();
    if (rel) {
      _path.quadraticBezierTo(_x + x1, _y + y1, _x + x, _y + y);
      _q1x = _x + x1;
      _q1y = _y + y1;
      _x += x;
      _y += y;
    } else {
      _path.quadraticBezierTo(x1, y1, x, y);
      _q1x = x1;
      _q1y = y1;
      _x = x;
      _y = y;
    }
  }

  void _smoothQuad(bool rel) {
    final x = _num(), y = _num();
    double cx, cy;
    if (_q1x != null) {
      cx = 2 * _x - _q1x!;
      cy = 2 * _y - _q1y!;
    } else {
      cx = _x;
      cy = _y;
    }
    if (rel) {
      _path.quadraticBezierTo(cx, cy, _x + x, _y + y);
      _x += x;
      _y += y;
    } else {
      _path.quadraticBezierTo(cx, cy, x, y);
      _x = x;
      _y = y;
    }
    _q1x = cx;
    _q1y = cy;
  }

  void _arc(bool rel) {
    final rx = _num().abs(), ry = _num().abs();
    final rot = _num();
    final large = _flag() == 1;
    final sweep = _flag() == 1;
    var x = _num(), y = _num();
    if (rel) {
      x += _x;
      y += _y;
    }
    _arcTo(rx, ry, rot, large, sweep, x, y);
    _c1x = _c1y = _q1x = _q1y = null;
    _x = x;
    _y = y;
  }

  /// SVG elliptical arc → cubic béziers (spec appendix A).
  void _arcTo(double rx, double ry, double rotDeg, bool large, bool sweep,
      double x2, double y2) {
    final x1 = _x, y1 = _y;
    if (rx == 0 || ry == 0) {
      _path.lineTo(x2, y2);
      return;
    }
    final phi = rotDeg * math.pi / 180;
    final cosP = math.cos(phi), sinP = math.sin(phi);
    final dx2 = (x1 - x2) / 2, dy2 = (y1 - y2) / 2;
    final x1p = cosP * dx2 + sinP * dy2;
    final y1p = -sinP * dx2 + cosP * dy2;

    final lambda = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry);
    if (lambda > 1) {
      final s = math.sqrt(lambda);
      rx *= s;
      ry *= s;
    }

    final sign = (large != sweep) ? 1.0 : -1.0;
    final num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    final den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    final co = sign * math.sqrt(math.max(0, num / den));
    final cxp = co * rx * y1p / ry;
    final cyp = -co * ry * x1p / rx;
    final cx = cosP * cxp - sinP * cyp + (x1 + x2) / 2;
    final cy = sinP * cxp + cosP * cyp + (y1 + y2) / 2;

    final ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry;
    final vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry;
    final theta1 = _vecAngle(1, 0, ux, uy);
    final dtheta = _vecAngle(ux, uy, vx, vy);
    final adjusted = (!sweep && dtheta > 0)
        ? dtheta - 2 * math.pi
        : (sweep && dtheta < 0)
            ? dtheta + 2 * math.pi
            : dtheta;

    final segments = (adjusted.abs() / (math.pi / 2)).ceil();
    final delta = adjusted / segments;
    final t = 4 / 3 * math.tan(delta / 4);

    for (var s = 0; s < segments; s++) {
      final th1 = theta1 + delta * s;
      final th2 = theta1 + delta * (s + 1);
      final p1 = _arcPoint(cx, cy, rx, ry, cosP, sinP, th1);
      final p4 = _arcPoint(cx, cy, rx, ry, cosP, sinP, th2);
      final d1 = _arcDeriv(rx, ry, cosP, sinP, th1);
      final d2 = _arcDeriv(rx, ry, cosP, sinP, th2);
      _path.cubicTo(
        p1[0] + t * d1[0],
        p1[1] + t * d1[1],
        p4[0] - t * d2[0],
        p4[1] - t * d2[1],
        p4[0],
        p4[1],
      );
    }
  }

  List<double> _arcPoint(double cx, double cy, double rx, double ry,
      double cosP, double sinP, double th) {
    final cosT = math.cos(th), sinT = math.sin(th);
    return [
      cx + rx * cosT * cosP - ry * sinT * sinP,
      cy + rx * cosT * sinP + ry * sinT * cosP,
    ];
  }

  List<double> _arcDeriv(
      double rx, double ry, double cosP, double sinP, double th) {
    final cosT = math.cos(th), sinT = math.sin(th);
    return [
      -rx * sinT * cosP - ry * cosT * sinP,
      -rx * sinT * sinP + ry * cosT * cosP,
    ];
  }

  double _vecAngle(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final len = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
    var a = math.acos((dot / len).clamp(-1.0, 1.0));
    if (ux * vy - uy * vx < 0) a = -a;
    return a;
  }
}
