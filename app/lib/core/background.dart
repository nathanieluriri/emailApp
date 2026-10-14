import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../mail/outbox.dart';
import '../notifications/reminders.dart';

/// WorkManager runs one entry point for every task: the outbox when the phone is back online, else the unread check.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, data) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      if (task == Reminders.task) {
        await Reminders.check();
        return true;
      }
      return await sendOutboxInBackground(task);
    } catch (_) {
      return task == Reminders.task;
    }
  });
}

Future<void>? _ready;

Future<void> ensureBackgroundWork() => _ready ??= Workmanager().initialize(backgroundDispatcher);
