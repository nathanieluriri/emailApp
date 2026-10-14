import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'quire/brand/quire_mark.dart';
import 'quire/theme/colors.dart';
import 'quire/theme/typography.dart';

const kAppName = 'Quirepost';

final _stroke = QuireMark.panes[3].holes.first.getBounds().left - QuireMark.panes[3].square.left;
final _envelopeHole = QuireMark.panes[3].holes.first.getBounds();

Path _pane(MarkPane p) => p.holes.fold(p.outline, (shape, hole) => Path.combine(PathOperation.difference, shape, hole));

final _paneShapes = [for (final p in QuireMark.panes) _pane(p)];

/// Quire's four panes, the last one folded into an envelope.
/// [gather] brings the three sheets in, [letter] drops a sheet into the envelope, [flap] closes it.
class MarkPainter extends CustomPainter {
  MarkPainter({required this.ink, required this.accent, this.gather = 1, this.letter = 1, this.flap = 1});

  final Color ink;
  final Color accent;
  final double gather;
  final double letter;
  final double flap;

  @override
  void paint(Canvas canvas, Size size) {
    final box = QuireMark.ink;
    final scale = size.shortestSide / box.longestSide;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-box.center.dx, -box.center.dy);

    for (var i = 0; i < 3; i++) {
      final t = Curves.easeOutBack.transform(((gather - i * 0.12) / 0.76).clamp(0.0, 1.0));
      final away = QuireMark.panes[i].centre - QuireMark.middle;
      canvas.save();
      canvas.translate(away.dx * 0.9 * (1 - t), away.dy * 0.9 * (1 - t) - 18 * (1 - t));
      canvas.drawPath(_paneShapes[i], Paint()..color = ink.withValues(alpha: ink.a * t.clamp(0.0, 1.0)));
      canvas.restore();
    }

    final envelope = Curves.easeOutBack.transform(((gather - 0.2) / 0.8).clamp(0.0, 1.0));
    final centre = QuireMark.panes[3].centre;
    canvas.save();
    canvas
      ..translate(centre.dx, centre.dy)
      ..scale(0.6 + 0.4 * envelope)
      ..translate(-centre.dx, -centre.dy);
    final paint = Paint()..color = accent.withValues(alpha: accent.a * envelope.clamp(0.0, 1.0));
    canvas.drawPath(_paneShapes[3], paint);

    if (letter > 0 && flap < 1) {
      final sheet = Rect.fromCenter(center: Offset(centre.dx, 0), width: _envelopeHole.width * 0.52, height: _envelopeHole.height * 0.62);
      final y = ui.lerpDouble(_envelopeHole.top - sheet.height / 2, _envelopeHole.center.dy + 2, Curves.easeOutCubic.transform(letter))!;
      canvas.save();
      canvas.clipRect(_envelopeHole);
      canvas.drawRRect(RRect.fromRectAndRadius(sheet.shift(Offset(0, y)), const Radius.circular(2.5)), paint);
      canvas.restore();
    }

    if (flap > 0) {
      final v = Path()
        ..moveTo(_envelopeHole.left, _envelopeHole.top)
        ..lineTo(centre.dx, _envelopeHole.top + _envelopeHole.height * 0.5)
        ..lineTo(_envelopeHole.right, _envelopeHole.top);
      final metric = v.computeMetrics().first;
      final drawn = Curves.easeOutCubic.transform(flap.clamp(0.0, 1.0));
      final half = metric.length / 2;
      canvas.drawPath(
        metric.extractPath(half - half * drawn, half + half * drawn),
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MarkPainter old) =>
      old.ink != ink || old.accent != accent || old.gather != gather || old.letter != letter || old.flap != flap;
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: MarkPainter(ink: AppColors.ink, accent: AppColors.accentBright),
  );
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    kAppName,
    style: AppText.markName.copyWith(color: AppColors.ink, fontSize: size),
  );
}
