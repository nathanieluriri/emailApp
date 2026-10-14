import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../constants/gooey_fab.dart';
import '../theme/colors.dart';

class GooCirclesPainter extends CustomPainter {
  const GooCirclesPainter({required this.actionCentresY, required this.buttonDiameter});

  final List<double> actionCentresY;

  final double buttonDiameter;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.accent;
    for (final centreY in actionCentresY) {
      _neck(canvas, paint, centreY);
      canvas.drawCircle(Offset(kFabCenterX, centreY), kGooActionDiameter / 2, paint);
    }
    canvas.drawCircle(const Offset(kFabCenterX, kFabCenterY), buttonDiameter / 2, paint);
  }

  void _neck(Canvas canvas, Paint paint, double centreY) {
    final travelled = (centreY - kFabCenterY).abs();
    if (travelled <= 0 || travelled >= kGooNeckBreak) return;
    final left = 1 - travelled / kGooNeckBreak;
    final buttonRadius = buttonDiameter / 2;
    const actionRadius = kGooActionDiameter / 2;
    for (var i = 1; i <= kGooNeckCircles; i++) {
      final along = i / (kGooNeckCircles + 1);
      final waist = 1 - (1 - kGooNeckWaist) * math.sin(along * math.pi);
      final radius = ui.lerpDouble(buttonRadius, actionRadius, along)! * waist * left;
      if (radius <= 0) continue;
      canvas.drawCircle(Offset(kFabCenterX, ui.lerpDouble(kFabCenterY, centreY, along)!), radius, paint);
    }
  }

  @override
  bool shouldRepaint(GooCirclesPainter oldDelegate) =>
      oldDelegate.buttonDiameter != buttonDiameter || !listEquals(oldDelegate.actionCentresY, actionCentresY);
}
