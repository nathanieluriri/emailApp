import 'dart:math';

import 'package:flutter/material.dart';

/// Gmail's party popper: paper bursts up from [origin], tumbles and drifts down out of sight.
void showConfetti(BuildContext context, Offset origin) {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Confetti(origin: origin, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.origin, required this.onDone});
  final Offset origin;
  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  static const _colors = [Color(0xFF1A9FE8), Color(0xFFFBBC04), Color(0xFFF48FB1), Color(0xFFFF8F00), Color(0xFFEA4335), Color(0xFF34A853)];
  late final _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward().whenComplete(widget.onDone);
  late final List<_Piece> _pieces = () {
    final random = Random();
    return List.generate(72, (i) => _Piece(random, _colors[i % _colors.length]))..sort((a, b) => a.depth.compareTo(b.depth));
  }();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(widget.origin, _pieces, _clock))),
  );
}

class _Piece {
  _Piece(Random r, this.color)
    : depth = 0.6 + pow(r.nextDouble(), 4) * 4.4,
      angle = -pi / 2 + (r.nextDouble() - 0.5) * 2.1,
      speed = 900 + r.nextDouble() * 1100,
      spin = (r.nextDouble() - 0.5) * 14,
      flip = 4 + r.nextDouble() * 8,
      sway = 12 + r.nextDouble() * 26,
      phase = r.nextDouble() * pi * 2,
      delay = r.nextDouble() * 0.12,
      aspect = 0.45 + r.nextDouble() * 0.5;

  final Color color;
  final double depth;
  final double angle;
  final double speed;
  final double spin;
  final double flip;
  final double sway;
  final double phase;
  final double delay;
  final double aspect;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.origin, this.pieces, this.clock) : super(repaint: clock);
  final Offset origin;
  final List<_Piece> pieces;
  final Animation<double> clock;

  static const _drag = 2.4;
  static const _gravity = 1500.0;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.value * 2.6;
    final paint = Paint();
    for (final p in pieces) {
      final t = seconds - p.delay;
      if (t <= 0) continue;
      final burst = (1 - exp(-_drag * t)) / _drag;
      final terminal = 260 + 120 * p.depth;
      final fall = terminal * t - terminal * terminal / _gravity * (1 - exp(-_gravity * t / terminal));
      final x = origin.dx + cos(p.angle) * p.speed * burst + sin(p.phase + t * 3) * p.sway * min(1, t * 2);
      final y = origin.dy + sin(p.angle) * p.speed * burst + fall;
      final life = (seconds / 2.6).clamp(0.0, 1.0);
      final fade = life < 0.7 ? 1.0 : 1 - (life - 0.7) / 0.3;
      final side = 9.0 * p.depth;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * t)
        ..scale(1, cos(p.phase + p.flip * t));
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: side, height: side * p.aspect),
        paint..color = p.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
