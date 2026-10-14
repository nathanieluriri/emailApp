import 'package:flutter/physics.dart';

class DelayedSimulation extends Simulation {
  DelayedSimulation({required this.delay, required this.hold, required this.build, this.carry});

  final double delay;

  final double hold;

  final Simulation Function(double value, double velocity) build;

  final Simulation? carry;

  Simulation? _handover;

  Simulation get _next => _handover ??= build(carry?.x(delay) ?? hold, carry?.dx(delay) ?? 0);

  @override
  double x(double time) => time < delay ? (carry?.x(time) ?? hold) : _next.x(time - delay);

  @override
  double dx(double time) => time < delay ? (carry?.dx(time) ?? 0) : _next.dx(time - delay);

  @override
  bool isDone(double time) => time >= delay && _next.isDone(time - delay);
}
