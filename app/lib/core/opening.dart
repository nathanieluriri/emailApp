import 'package:flutter/material.dart';

import 'brand.dart';
import 'quire/theme/colors.dart';
import 'quire/theme/easings.dart';
import 'quire/theme/feedback.dart';

const kOpening = Duration(milliseconds: 1500);

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// The launch: three sheets gather into the mark, a letter drops into the envelope,
/// the flap closes, and the app rises out from behind it.
class Opening extends StatefulWidget {
  const Opening({super.key, required this.child});
  final Widget child;

  @override
  State<Opening> createState() => _OpeningState();
}

class _OpeningState extends State<Opening> with SingleTickerProviderStateMixin {
  static bool _played = false;
  late final _c = AnimationController(vsync: this, duration: kOpening);
  bool _done = _played;
  bool _ticked = false;

  @override
  void initState() {
    super.initState();
    if (_done) return;
    _played = true;
    _c.addListener(() {
      if (!_ticked && _c.value > 0.62) {
        _ticked = true;
        Feel.tap.ring();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _c.duration = const Duration(milliseconds: 240);
        _c.value = 0.8;
      }
      _c.forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, app) {
        final t = _c.value;
        final reveal = easeOutCubic.transform(_span(t, 0.72, 1));
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(scale: 1.05 - 0.05 * reveal, child: app),
            IgnorePointer(
              ignoring: reveal > 0.3,
              child: Opacity(
                opacity: 1 - reveal,
                child: ColoredBox(
                  color: AppColors.ground,
                  child: Center(
                    child: Transform.scale(
                      scale: 1 - 0.12 * easeInCubic.transform(_span(t, 0.7, 1)),
                      child: CustomPaint(
                        size: const Size.square(112),
                        painter: MarkPainter(
                          ink: AppColors.ink,
                          accent: AppColors.accentBright,
                          gather: _span(t, 0, 0.36),
                          letter: _span(t, 0.3, 0.5),
                          flap: _span(t, 0.5, 0.66),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
