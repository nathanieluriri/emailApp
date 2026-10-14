import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_service.dart';

final pushStatusProvider = NotifierProvider<PushStatusController, PushStatus>(PushStatusController.new);

class PushStatusController extends Notifier<PushStatus> {
  @override
  PushStatus build() {
    final sub = PushService.changes.stream.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return PushService.status;
  }
}
