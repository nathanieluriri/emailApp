import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../theme/colors.dart';

const double kSpinnerSize = 48.0;

const double kSpinnerStroke = 3.5;

const double kSpinnerSweep = 300.0;

const Duration kSpinnerPeriod = Duration(milliseconds: 1100);

const double kSpinnerWave = 2.5;

const int kSpinnerWaveCycles = 9;

const double kSpinnerCrestsPerTurn = kSpinnerWaveCycles * 360.0 / kSpinnerSweep - 1;

const int kSpinnerSegments = kSpinnerWaveCycles * 24;

const double kSpinnerStartAngle = -math.pi / 2;

const Duration kSpinnerTrace = Duration(milliseconds: 700);

class SpinnerPainter extends CustomPainter {
  const SpinnerPainter({required this.turns, this.color, this.arc = 1, this.trace = 1});

  final double turns;

  final Color? color;

  final double arc;

  final double trace;

  static double meanRadius(Size size) => math.min(size.width, size.height) / 2 - kSpinnerStroke / 2 - kSpinnerWave;

  static Offset pointAt(double u, double turns, Offset centre, double mean, {double trace = 1}) {
    final phase = turns * 2 * math.pi;
    final angle = kSpinnerStartAngle + phase + kSpinnerSweep * math.pi / 180 * u;
    final height = trace >= 1 ? 1.0 : ((trace - u) * 4).clamp(0.0, 1.0);
    final radius = mean + kSpinnerWave * height * math.sin(kSpinnerWaveCycles * 2 * math.pi * u + phase);
    return centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final mean = meanRadius(size);
    if (mean <= 0) return;
    final drawn = arc.clamp(0.0, 1.0);
    if (drawn <= 0) return;
    final path = Path();
    for (var i = 0; i <= kSpinnerSegments; i++) {
      final point = pointAt(i / kSpinnerSegments * drawn, turns, centre, mean, trace: trace);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color ?? AppColors.accentBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = kSpinnerStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(SpinnerPainter old) => old.turns != turns || old.color != color || old.arc != arc || old.trace != trace;
}
