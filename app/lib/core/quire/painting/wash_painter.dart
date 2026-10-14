import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

const kWashLobes = 5;

const kWashLobeSpread = 0.55;

const kWashWell = 26.0;

class WashPainter extends CustomPainter {
  const WashPainter({required this.at, required this.well, required this.flood, required this.colour});

  final Offset at;

  final double well;

  final double flood;

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (well <= 0 && flood <= 0) return;
    final paint = Paint()..color = colour;
    var reach = 0.0;
    for (final corner in <Offset>[Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)]) {
      reach = math.max(reach, (corner - at).distance);
    }
    final radius = ui.lerpDouble(kWashWell * well, reach + kWashWell, flood)!;
    final spread = radius * kWashLobeSpread * (1 - flood);
    for (var i = 0; i < kWashLobes; i++) {
      final angle = i * 2 * math.pi / kWashLobes;
      final breathe = 0.8 + 0.2 * math.sin(well * math.pi * (1 + i * 0.37));
      canvas.drawCircle(at + Offset(math.cos(angle), math.sin(angle)) * spread, radius * breathe, paint);
    }
  }

  @override
  bool shouldRepaint(WashPainter oldDelegate) =>
      oldDelegate.at != at || oldDelegate.well != well || oldDelegate.flood != flood || oldDelegate.colour != colour;
}
