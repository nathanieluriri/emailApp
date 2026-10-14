import 'dart:async';

import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../accounts/account.dart';
import '../core/config.dart';

class PushEvent {
  const PushEvent({required this.host, this.threadId, this.messageId, this.title, this.body, required this.opened});
  final String? host;
  final String? threadId;
  final String? messageId;
  final String? title;
  final String? body;
  final bool opened;
}

/// Devices carry `worker_host=<active host>` plus `wh_<host>=1` for every saved account,
/// so one device receives pushes for all of its accounts.
abstract final class PushService {
  static const pushIdsKey = 'push_ids';
  static const optedInKey = 'push_opted_in';
  static final events = StreamController<PushEvent>.broadcast();
  static PushEvent? pendingOpen;

  static String hostTag(String host) => 'wh_$host';

  static Future<void> init() async {
    OneSignal.initialize(AppConfig.oneSignalAppId);
    OneSignal.Notifications.addClickListener((e) => _emit(e.notification, opened: true));
    OneSignal.Notifications.addForegroundWillDisplayListener((e) {
      e.preventDefault();
      _emit(e.notification, opened: false);
    });
    OneSignal.User.pushSubscription.addObserver((s) => _saveOptedIn(s.current.optedIn));
  }

  static Future<void> _emit(OSNotification n, {required bool opened}) async {
    final data = n.additionalData ?? {};
    final event = PushEvent(
      host: data['host'] as String?,
      threadId: data['threadId'] as String?,
      messageId: data['messageId'] as String?,
      title: n.title,
      body: n.body,
      opened: opened,
    );
    final prefs = await SharedPreferences.getInstance();
    if (event.messageId != null) {
      final ids = [...prefs.getStringList(pushIdsKey) ?? <String>[], event.messageId!];
      await prefs.setStringList(pushIdsKey, ids.length > 300 ? ids.sublist(ids.length - 300) : ids);
    }
    if (opened && !events.hasListener) pendingOpen = event;
    events.add(event);
  }

  static Future<void> _saveOptedIn(bool optedIn) async => (await SharedPreferences.getInstance()).setBool(optedInKey, optedIn);

  static Future<bool> requestPermission() async {
    final granted = await OneSignal.Notifications.requestPermission(true);
    await _saveOptedIn(granted);
    return granted;
  }

  static bool get permitted => OneSignal.Notifications.permission;

  static Future<void> syncTags(List<Account> accounts, {Account? active}) async {
    if (accounts.isEmpty) return;
    await OneSignal.User.addTags({'worker_host': (active ?? accounts.first).host, for (final a in accounts) hostTag(a.host): '1'});
  }

  static Future<void> removeTag(Account removed, List<Account> remaining) async {
    if (remaining.any((a) => a.host == removed.host)) return;
    await OneSignal.User.removeTags([hostTag(removed.host), if (remaining.isEmpty) 'worker_host']);
  }
}
