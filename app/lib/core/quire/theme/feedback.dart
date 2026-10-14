import 'package:flutter/services.dart';

enum Feel {
  none,

  tap,

  turn,

  commit;

  void ring() {
    switch (this) {
      case Feel.none:
        return;
      case Feel.tap:
        HapticFeedback.selectionClick();
      case Feel.turn:
        HapticFeedback.lightImpact();
      case Feel.commit:
        HapticFeedback.mediumImpact();
    }
  }
}
