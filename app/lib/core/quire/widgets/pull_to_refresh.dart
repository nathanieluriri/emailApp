import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

import '../config/flags.dart';
import '../painting/spinner_painter.dart';
import '../theme/colors.dart';
import '../theme/feedback.dart';

const kPullThreshold = 76.0;

const kPullLimit = 128.0;

const kPullRest = 60.0;

const kPullHold = Duration(milliseconds: 180);

const kPullRetract = Duration(milliseconds: 110);
const kPullPrompt = Duration(milliseconds: 1);

const kGooFollow = Duration(milliseconds: 110);
const kGooReturn = Duration(milliseconds: 300);

const double kGooSettled = 0.4;

const double kGooStretchAt = 900.0;
const double kGooStretch = 0.42;

const double kPullTurns = 0.75;

const double kNeckHug = 5.0;

const double kGooWobble = 0.055;

const int kGooLobes = 3;

const double kPullHush = 0.34;

class PullToRefresh extends StatefulWidget {
  const PullToRefresh({super.key, required this.child, required this.onRefresh, this.enabled = true, this.style = kPullStyle});

  final PullStyle style;

  final Widget child;

  final Future<void> Function() onRefresh;

  final bool enabled;

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> with TickerProviderStateMixin {
  double _pull = 0;

  bool _working = false;

  bool _armed = false;

  late final AnimationController _turn;

  late final AnimationController _trace;

  bool _going = false;

  double _here = 0;
  double _speed = 0;
  Duration _last = Duration.zero;
  Ticker? _ooze;

  Completer<void>? _home;

  @override
  void initState() {
    super.initState();
    _turn = AnimationController(vsync: this, duration: kSpinnerPeriod);
    _trace = AnimationController(vsync: this, duration: kSpinnerTrace);
  }

  @override
  void dispose() {
    _ooze?.dispose();
    _turn.dispose();
    _trace.dispose();
    super.dispose();
  }

  double get _wanted {
    if (_going) return 0;
    if (_working) return kPullRest;
    return _pull;
  }

  double get _shown => _here;

  void _startOozing() {
    if (_ooze != null) return;
    _last = Duration.zero;
    _ooze = createTicker(_onOoze)..start();
  }

  void _onOoze(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    final wanted = _wanted;
    final thick = widget.style == PullStyle.goo;
    final going = _going || (!_working && wanted <= 0);
    final tau = (thick ? (going ? kGooReturn : kGooFollow) : (going ? kPullRetract : kPullPrompt)).inMicroseconds / 1e6;
    final step = 1 - math.exp(-dt / tau);
    final next = _here + (wanted - _here) * step;
    _speed = (next - _here) / dt;
    setState(() => _here = next);
    if ((wanted - _here).abs() > kGooSettled || _working) {
      if (_working && !_going) return;
      if ((wanted - _here).abs() > kGooSettled) return;
    }
    setState(() {
      _here = wanted;
      _speed = 0;
    });
    if (wanted <= 0) {
      _ooze?.dispose();
      _ooze = null;
      _home?.complete();
      _home = null;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.enabled || _working) return false;
    if (notification.depth != 0) return false;

    if (notification is OverscrollNotification) {
      final over = notification.overscroll;
      if (over >= 0 || notification.metrics.pixels > 0) return false;
      _setPull((_pull - over).clamp(0.0, kPullLimit));
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      final past = -notification.metrics.pixels;
      if (past > 0) {
        _setPull(past.clamp(0.0, kPullLimit));
        if (notification.dragDetails == null && _pull >= kPullThreshold) {
          unawaited(_run());
        }
        return false;
      }
      if (_pull > 0) {
        final delta = notification.scrollDelta ?? 0;
        if (delta > 0) _setPull((_pull - delta).clamp(0.0, kPullLimit));
      }
      return false;
    }
    if (notification is ScrollEndNotification && _pull > 0) {
      if (_pull >= kPullThreshold) {
        unawaited(_run());
      } else {
        _setPull(0);
      }
      return false;
    }
    return false;
  }

  void _setPull(double next) {
    if (next == _pull) return;
    setState(() => _pull = next);
    _startOozing();
    final past = _pull >= kPullThreshold;
    if (past && !_armed) {
      _armed = true;
      Feel.turn.ring();
    } else if (!past) {
      _armed = false;
    }
  }

  Future<void> _run() async {
    setState(() {
      _working = true;
      _going = false;
      _pull = kPullRest;
    });
    _startOozing();
    _trace.forward(from: 0);
    _turn.repeat();
    Feel.commit.ring();
    try {
      await widget.onRefresh();
    } finally {
      await _settle();
    }
  }

  Future<void> _settle() async {
    if (!mounted) return;
    await Future<void>.delayed(kPullHold);
    if (!mounted) return;
    final home = _home = Completer<void>();
    setState(() => _going = true);
    _startOozing();
    await home.future;
    if (!mounted) return;
    _turn.stop();
    _trace.value = 0;
    setState(() {
      _working = false;
      _going = false;
      _pull = 0;
      _armed = false;
      _speed = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_turn, _trace]),
        builder: (context, _) {
          final down = _shown;
          final reach = (_pull / kPullThreshold).clamp(0.0, 1.0);
          final goo = widget.style == PullStyle.goo;
          final loop = _Loop(
            down: down,
            turns: _working ? _turn.value : reach * kPullTurns,
            reach: reach,
            working: _working,
            trace: _working && !goo ? _trace.value : 0,
            attach: _working && !_going ? 0 : 1 - (down / kPullThreshold).clamp(0.0, 1.0),
            stretch: (_speed / kGooStretchAt).clamp(-1.0, 1.0) * kGooStretch,
            style: widget.style,
          );
          final hush = goo && _working ? kPullHush * _trace.value * (down / kPullRest).clamp(0.0, 1.0) : 0.0;
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: Hushed(
                  quiet: hush > 0 ? (hush / kPullHush).clamp(0.0, 1.0) : 0,
                  child: switch (widget.style) {
                    PullStyle.follow => Transform.translate(offset: Offset(0, down), child: widget.child),
                    PullStyle.overlay || PullStyle.goo => widget.child,
                  },
                ),
              ),
              if (hush > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: AppColors.ground.withValues(alpha: hush)),
                  ),
                ),
              if (_pull > 0 || _working) Positioned(left: 0, right: 0, top: 0, child: IgnorePointer(child: loop)),
            ],
          );
        },
      ),
    );
  }
}

class _Loop extends StatelessWidget {
  const _Loop({
    required this.down,
    required this.turns,
    required this.reach,
    required this.working,
    required this.trace,
    required this.attach,
    required this.stretch,
    required this.style,
  });

  final double trace;

  final double attach;

  final double stretch;

  final PullStyle style;

  final double down;

  final double turns;

  final double reach;

  final bool working;

  @override
  Widget build(BuildContext context) {
    final size = kSpinnerSize * (0.55 + 0.45 * reach);
    final held = style == PullStyle.goo;
    final colour = held
        ? AppColors.onAccent
        : working || reach >= 1
        ? AppColors.accentBright
        : AppColors.inkFaint;
    final centre = switch (style) {
      PullStyle.follow => ((down - kSpinnerSize) / 2).clamp(0.0, kPullLimit),
      PullStyle.overlay || PullStyle.goo => (down - kSpinnerSize / 2).clamp(0.0, kPullLimit),
    };
    return SizedBox(
      height: (centre + kSpinnerSize).clamp(0.0, kPullLimit + kSpinnerSize),
      child: Stack(
        children: <Widget>[
          if (style == PullStyle.goo)
            Positioned.fill(
              child: CustomPaint(
                painter: _GooPainter(
                  centreY: centre + kSpinnerSize / 2,
                  radius: size / 2 + kNeckHug,
                  attach: attach,
                  stretch: stretch,
                  phase: turns,
                  working: working,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: centre,
            child: Center(
              child: Opacity(
                opacity: working ? 1 : reach.clamp(0.0, 1.0),
                child: SizedBox.square(
                  dimension: kSpinnerSize,
                  child: Center(
                    child: SizedBox.square(
                      dimension: size,
                      child: CustomPaint(
                        painter: SpinnerPainter(turns: turns, color: colour, arc: working ? 1 : reach, trace: trace),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GooPainter extends CustomPainter {
  const _GooPainter({
    required this.centreY,
    required this.radius,
    required this.attach,
    required this.stretch,
    required this.phase,
    required this.working,
  });

  final double centreY;

  final double radius;

  final double attach;

  final double stretch;

  final double phase;

  final bool working;

  @override
  void paint(Canvas canvas, Size size) {
    if (centreY <= 0 || radius <= 0) return;
    final x = size.width / 2;
    final paint = Paint()..color = AppColors.accent;
    final joined = attach.clamp(0.0, 1.0);
    if (joined > 0) {
      canvas.drawPath(_neck(x), paint);
    }
    canvas.drawPath(_body(x), paint);
  }

  Path _neck(double x) {
    final joined = attach.clamp(0.0, 1.0);
    final head = radius * (0.45 + 0.7 * joined);
    final waist = radius * (0.12 + 0.46 * joined);
    final meet = centreY - radius * 0.72;
    return Path()
      ..moveTo(x - head, 0)
      ..cubicTo(x - head, meet * 0.42, x - waist, meet * 0.34, x - waist, meet * 0.62)
      ..cubicTo(x - waist, meet * 0.92, x - radius * 0.9, meet, x - radius, centreY)
      ..lineTo(x + radius, centreY)
      ..cubicTo(x + radius * 0.9, meet, x + waist, meet * 0.92, x + waist, meet * 0.62)
      ..cubicTo(x + waist, meet * 0.34, x + head, meet * 0.42, x + head, 0)
      ..close();
  }

  Path _body(double x) {
    final swell = kGooWobble * (working ? 1 : 0.45);
    final turn = phase * 2 * math.pi;
    final along = 1 + stretch.abs();
    final across = 1 - stretch.abs() * 0.45;
    final path = Path();
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final angle = i / steps * 2 * math.pi;
      final r = radius * (1 + swell * math.sin(kGooLobes * angle + turn));
      final point = Offset(x + math.cos(angle) * r * across, centreY + math.sin(angle) * r * along);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_GooPainter old) =>
      old.centreY != centreY ||
      old.radius != radius ||
      old.attach != attach ||
      old.stretch != stretch ||
      old.phase != phase ||
      old.working != working;
}

class Hushed extends InheritedWidget {
  const Hushed({super.key, required this.quiet, required super.child});

  final double quiet;

  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Hushed>()?.quiet ?? 0;

  @override
  bool updateShouldNotify(Hushed old) => old.quiet != quiet;
}
