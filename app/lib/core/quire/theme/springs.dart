import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'metrics.dart';

abstract final class AppSprings {
  static const peelSnap = SpringDescription(mass: 1, stiffness: 260, damping: 22);

  static const dockScale = SpringDescription(mass: 1, stiffness: 260, damping: 20);

  static const shelfLayout = SpringDescription(mass: 1, stiffness: 200, damping: 30);

  static const pageSettle = SpringDescription(mass: 1, stiffness: 180, damping: 26);

  static final gooHead = SpringDescription.withDampingRatio(mass: 1, stiffness: 110, ratio: 0.88);

  static final gooTail = SpringDescription.withDampingRatio(mass: 1, stiffness: 46, ratio: 1);

  static final gooSpread = SpringDescription.withDampingRatio(mass: 1, stiffness: 150, ratio: 0.72);

  static final gooRise = SpringDescription.withDampingRatio(mass: 1, stiffness: 180, ratio: 1);

  static final gooSet = SpringDescription.withDampingRatio(mass: 1, stiffness: 80, ratio: 1);

  static final gooGiveWay = SpringDescription.withDampingRatio(mass: 1, stiffness: 120, ratio: 1);

  static final litLead = SpringDescription.withDampingRatio(mass: 1, stiffness: 120, ratio: 1);
  static final litTrail = SpringDescription.withDampingRatio(mass: 1, stiffness: 60, ratio: 1);

  static final reveal = SpringDescription.withDampingRatio(mass: 1, stiffness: 110, ratio: 1);

  static final barRise = SpringDescription.withDampingRatio(mass: 1, stiffness: 90, ratio: 1);
  static final barFall = SpringDescription.withDampingRatio(mass: 1, stiffness: 140, ratio: 1);
  static final barNote = SpringDescription.withDampingRatio(mass: 1, stiffness: 110, ratio: 1);

  static final band = SpringDescription.withDampingRatio(mass: 1, stiffness: 160, ratio: 1);

  static const drawer = SpringDescription(mass: 1, stiffness: 210, damping: 24);

  static final drawerRatio = drawer.damping / (2 * math.sqrt(drawer.stiffness * drawer.mass));

  static final documentArrival = SpringDescription.withDampingRatio(
    mass: drawer.mass,
    stiffness: drawer.stiffness * (drawerWidth(kScreenWidth) / kScreenWidth) * (drawerWidth(kScreenWidth) / kScreenWidth),
    ratio: drawerRatio,
  );
}

class SpringValue {
  SpringValue(double value, {this.tolerance = pointTolerance}) : _to = value;

  static const pointTolerance = Tolerance(distance: 0.25, velocity: 2.5);

  static const shareTolerance = Tolerance(distance: 0.004, velocity: 0.02);

  final Tolerance tolerance;

  SpringSimulation? _run;
  SpringDescription? _spring;
  double _began = 0;
  double _to;

  double get target => _to;

  double valueAt(double now) {
    final run = _run;
    return run == null ? _to : run.x(math.max(0, now - _began));
  }

  double velocityAt(double now) {
    final run = _run;
    if (run == null || run.isDone(math.max(0, now - _began))) return 0;
    return run.dx(math.max(0, now - _began));
  }

  bool restingAt(double now) {
    final run = _run;
    return run == null || run.isDone(math.max(0, now - _began));
  }

  void sendTo(double target, double now, SpringDescription spring) {
    if (target == _to) return;
    _spring = spring;
    _run = SpringSimulation(spring, valueAt(now), target, velocityAt(now), tolerance: tolerance, snapToEnd: true);
    _began = now;
    _to = target;
  }

  void jumpTo(double value) {
    _run = null;
    _to = value;
  }

  void shiftBy(double delta, double now) {
    if (delta == 0) return;
    final run = _run;
    final spring = _spring;
    if (run == null || spring == null || restingAt(now)) {
      jumpTo(valueAt(now) + delta);
      return;
    }
    final at = valueAt(now) + delta;
    final speed = velocityAt(now);
    _to += delta;
    _run = SpringSimulation(spring, at, _to, speed, tolerance: tolerance, snapToEnd: true);
    _began = now;
  }
}

class SpringCurve extends Curve {
  SpringCurve(SpringDescription spring, {required this.duration, bool clampOvershoot = false})
    : _simulation = SpringSimulation(spring, 0, 1, 0),
      _clampSeconds = clampOvershoot ? _firstOvershootSeconds(spring) : double.infinity;

  final Duration duration;
  final SpringSimulation _simulation;
  final double _clampSeconds;

  @override
  double transformInternal(double t) {
    final seconds = t * duration.inMicroseconds / 1e6;
    if (seconds >= _clampSeconds) {
      return 1;
    }
    return _simulation.x(seconds);
  }
}

double _firstOvershootSeconds(SpringDescription spring) {
  final simulation = SpringSimulation(spring, 0, 1, 0);
  for (var ms = 1; ms <= _searchMs; ms++) {
    if (simulation.x(ms / 1000) >= 1) {
      return ms / 1000;
    }
  }
  return double.infinity;
}

const _searchMs = 4000;

Duration springDuration(SpringDescription spring, {bool clampOvershoot = false}) {
  if (clampOvershoot) {
    final seconds = _firstOvershootSeconds(spring);
    if (seconds.isFinite) {
      return Duration(milliseconds: (seconds * 1000).round());
    }
  }
  final simulation = SpringSimulation(spring, 0, 1, 0);
  for (var ms = 1; ms <= _searchMs; ms++) {
    if (simulation.isDone(ms / 1000)) {
      return Duration(milliseconds: ms);
    }
  }
  return const Duration(milliseconds: _searchMs);
}
