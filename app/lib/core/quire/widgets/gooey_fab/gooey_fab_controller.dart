import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../constants/gooey_fab.dart';
import 'delayed_simulation.dart';

class _Drive {
  _Drive(this.controller);

  final AnimationController controller;
  SpringDescription? spring;
  double? target;

  Simulation? get inFlight {
    if (!controller.isAnimating || spring == null) {
      return null;
    }
    return SpringSimulation(spring!, controller.value, target!, controller.velocity);
  }
}

class GooeyFabController extends ChangeNotifier {
  GooeyFabController({required TickerProvider vsync, int? actionCount})
    : progress = AnimationController.unbounded(vsync: vsync),
      scrim = AnimationController(vsync: vsync, duration: kFabScrimFade) {
    _progress = _Drive(progress);
    _actions = List<_Drive>.generate(actionCount ?? kFabActions.length, (_) => _Drive(AnimationController.unbounded(vsync: vsync)));
    animations = Listenable.merge(<Listenable>[progress, for (final drive in _actions) drive.controller]);
  }

  final AnimationController progress;

  final AnimationController scrim;

  late final _Drive _progress;
  late final List<_Drive> _actions;

  Animation<double> actionDrive(int index) => _actions[index].controller;

  int get actionCount => _actions.length;

  bool get isOpen => _isOpen;
  bool _isOpen = false;

  late final Listenable animations;

  void toggle() {
    if (_isOpen) {
      _springTo(_progress, 0, kFabCloseSpring);
      for (var i = _actions.length - 1; i >= 0; i--) {
        _springTo(_actions[i], 0, kFabCloseSpring, delay: kFabActionStagger * (_actions.length - 1 - i));
      }
      scrim.reverse();
    } else {
      _springTo(_progress, 1, kFabOpenSpring);
      for (var i = 0; i < _actions.length; i++) {
        _springTo(_actions[i], 1, i == 1 ? kFabLooseOpenSpring : kFabOpenSpring, delay: kFabActionStagger * i);
      }
      scrim.forward();
    }
    _isOpen = !_isOpen;
    notifyListeners();
  }

  void _springTo(_Drive drive, double target, SpringDescription spring, {Duration delay = Duration.zero}) {
    final controller = drive.controller;
    final from = controller.value;
    final velocity = controller.velocity;
    final carry = delay == Duration.zero ? null : drive.inFlight;
    drive.spring = spring;
    drive.target = target;

    if (delay == Duration.zero) {
      controller.animateWith(SpringSimulation(spring, from, target, velocity));
      return;
    }
    controller.animateWith(
      DelayedSimulation(
        delay: delay.inMicroseconds / Duration.microsecondsPerSecond,
        hold: from,
        carry: carry,
        build: (value, velocity) => SpringSimulation(spring, value, target, velocity),
      ),
    );
  }

  @override
  void dispose() {
    progress.dispose();
    scrim.dispose();
    for (final drive in _actions) {
      drive.controller.dispose();
    }
    super.dispose();
  }
}
