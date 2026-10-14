import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'quire/theme/easings.dart';
import 'quire/theme/metrics.dart';
import 'quire/theme/springs.dart';

final _arrivalTime = springDuration(AppSprings.documentArrival, clampOvershoot: true);
final _arrival = SpringCurve(AppSprings.documentArrival, duration: _arrivalTime, clampOvershoot: true);

/// Quire's document arrival: the page slides in from the right edge on the drawer's spring.
CustomTransitionPage<void> slidePage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: _arrivalTime,
  reverseTransitionDuration: kCloseDocument,
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: _arrival, reverseCurve: easeInCubic)),
    child: FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.6).animate(CurvedAnimation(parent: secondary, curve: easeOutCubic)),
      child: child,
    ),
  ),
);

/// Quire's full-screen pad: slides up from the bottom.
CustomTransitionPage<void> padPage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: kPadArrival,
  reverseTransitionDuration: kPadArrival,
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: easeOutCubic)),
    child: child,
  ),
);

/// Quire's present route: fade with a scale from 0.92.
CustomTransitionPage<void> fadeScalePage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: kPadArrival,
  transitionsBuilder: (context, animation, secondary, child) {
    final t = CurvedAnimation(parent: animation, curve: easeOutCubic);
    return FadeTransition(
      opacity: t,
      child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(t), child: child),
    );
  },
);

/// List rows settle into place on Quire's shelf spring, staggered by position.
class EntryMotion extends StatefulWidget {
  const EntryMotion({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<EntryMotion> createState() => _EntryMotionState();
}

class _EntryMotionState extends State<EntryMotion> with SingleTickerProviderStateMixin {
  static final _duration = springDuration(AppSprings.shelfLayout);
  static final _curve = SpringCurve(AppSprings.shelfLayout, duration: _duration);
  late final _c = AnimationController(vsync: this, duration: _duration);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 24 * widget.index.clamp(0, 10)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = _curve.transform(_c.value);
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      );
    },
    child: widget.child,
  );
}
