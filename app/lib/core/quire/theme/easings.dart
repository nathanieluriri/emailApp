import 'package:flutter/animation.dart';

class EaseOutQuad extends Curve {
  const EaseOutQuad();

  @override
  double transformInternal(double t) => 1 - (1 - t) * (1 - t);
}

class EaseOutCubic extends Curve {
  const EaseOutCubic();

  @override
  double transformInternal(double t) {
    final inverse = 1 - t;
    return 1 - inverse * inverse * inverse;
  }
}

class EaseInOutQuad extends Curve {
  const EaseInOutQuad();

  @override
  double transformInternal(double t) {
    if (t < 0.5) {
      return 2 * t * t;
    }
    final inverse = 1 - t;
    return 1 - 2 * inverse * inverse;
  }
}

const easeOutQuad = EaseOutQuad();
const easeOutCubic = EaseOutCubic();
const easeInOutQuad = EaseInOutQuad();

class EaseInOutCubic extends Curve {
  const EaseInOutCubic();

  @override
  double transformInternal(double t) {
    if (t < 0.5) {
      return 4 * t * t * t;
    }
    final inverse = 2 - 2 * t;
    return 1 - inverse * inverse * inverse / 2;
  }
}

class EaseInCubic extends Curve {
  const EaseInCubic();

  @override
  double transformInternal(double t) => t * t * t;
}

const easeInOutCubic = EaseInOutCubic();
const easeInCubic = EaseInCubic();
