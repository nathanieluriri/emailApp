import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../constants/gooey_fab.dart' show kGooNeckWaist;
import '../theme/easings.dart';

const kTabGooThreadPitch = 14.0;

const kTabGooGatherEnd = 0.2;
const kTabGooTravelEnd = 0.7;
const kTabGooArriveStart = 0.55;
const kTabGooWidenEnd = 0.85;

const kTabGooViscousOpenStart = 0.45;

class TabGooPainter extends CustomPainter {
  const TabGooPainter({required this.from, required this.to, required this.t, required this.colour, this.viscous = false});

  final Rect from;

  final Rect to;

  final double t;

  final Color colour;

  final bool viscous;

  static double _stage(double t, double start, double end) => ((t - start) / (end - start)).clamp(0.0, 1.0);

  static Rect bodyAt({required Rect from, required Rect to, required double t, bool viscous = false}) {
    double eased(double share) => viscous ? easeOutCubic.transform(share) : share;
    if (t < kTabGooGatherEnd) {
      final gather = _stage(t, 0, kTabGooGatherEnd);
      return Rect.fromCenter(
        center: from.center,
        width: ui.lerpDouble(from.width, from.height, viscous ? easeInOutCubic.transform(gather) : gather)!,
        height: from.height,
      );
    }
    final radius = math.min(from.height, to.height) / 2;
    final travel = (viscous ? easeInOutCubic : easeInOutQuad).transform(_stage(t, kTabGooGatherEnd, kTabGooTravelEnd));
    final blob = Rect.fromCircle(center: Offset.lerp(from.center, to.center, travel)!, radius: radius);
    if (viscous && t >= kTabGooViscousOpenStart) {
      final open = _opening(to, t);
      return open.width >= blob.width ? open : blob;
    }
    if (t < kTabGooTravelEnd) return blob;
    final widen = eased(_stage(t, kTabGooTravelEnd, kTabGooWidenEnd));
    return Rect.fromCenter(center: to.center, width: ui.lerpDouble(to.height, to.width, widen)!, height: to.height);
  }

  static Rect _opening(Rect chip, double t) {
    final open = easeInOutQuad.transform(_stage(t, kTabGooViscousOpenStart, kTabGooWidenEnd));
    final width = chip.width * open;
    return Rect.fromCenter(center: chip.center, width: width, height: math.min(chip.height, width));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colour;
    final radius = math.min(from.height, to.height) / 2;

    final gather = _stage(t, 0, kTabGooGatherEnd);
    if (gather < 1) {
      _pill(canvas, paint, from, ui.lerpDouble(from.width, from.height, viscous ? easeInOutCubic.transform(gather) : gather)!);
    }

    final travel = (viscous ? easeInOutCubic : easeInOutQuad).transform(_stage(t, kTabGooGatherEnd, kTabGooTravelEnd));
    final blob = Offset.lerp(from.center, to.center, travel)!;
    canvas.drawCircle(blob, radius, paint);

    if (t > kTabGooGatherEnd && travel < 1) {
      _thread(canvas, paint, from.center, blob, radius, 1 - travel);
    }

    if (viscous) {
      final open = _opening(to, t);
      if (open.width > 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(open, Radius.circular(open.height / 2)), paint);
      }
      return;
    }
    final arrive = _eased(_stage(t, kTabGooArriveStart, kTabGooTravelEnd));
    final widen = _eased(_stage(t, kTabGooTravelEnd, kTabGooWidenEnd));
    if (arrive > 0) {
      if (widen > 0) {
        _pill(canvas, paint, to, ui.lerpDouble(to.height, to.width, widen)!);
      } else {
        canvas.drawCircle(to.center, radius * arrive, paint);
      }
    }
  }

  double _eased(double share) => viscous ? easeOutCubic.transform(share) : share;

  void _pill(Canvas canvas, Paint paint, Rect chip, double width) {
    if (width <= 0) return;
    final body = Rect.fromCenter(center: chip.center, width: width, height: chip.height);
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(chip.height / 2)), paint);
  }

  void _thread(Canvas canvas, Paint paint, Offset tail, Offset head, double radius, double strength) {
    final span = head - tail;
    final count = math.max(2, (span.distance / kTabGooThreadPitch).ceil());
    for (var i = 1; i < count; i++) {
      final along = i / count;
      final waist = 1 - (1 - kGooNeckWaist) * math.sin(along * math.pi);
      final r = radius * waist * strength;
      if (r <= 0) continue;
      canvas.drawCircle(tail + span * along, r, paint);
    }
  }

  @override
  bool shouldRepaint(TabGooPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.t != t ||
      oldDelegate.colour != colour ||
      oldDelegate.viscous != viscous;
}
