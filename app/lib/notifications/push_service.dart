import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../accounts/account.dart';
import '../core/api/api_client.dart';
import '../core/config.dart';

enum PushAction { open, reply }

class PushEvent {
  const PushEvent({
    required this.host,
    this.threadId,
    this.messageId,
    this.sender,
    this.subject,
    this.snippet,
    this.account,
    this.quiet = false,
    this.action = PushAction.open,
    this.text,
    required this.opened,
  });

  final String? host;
  final String? threadId;
  final String? messageId;
  final String? sender;
  final String? subject;
  final String? snippet;
  final String? account;
  final bool quiet;
  final PushAction action;

  /// A reply typed in a notification that could not be sent, to finish in the composer.
  final String? text;
  final bool opened;
}

class PushStatus {
  const PushStatus({this.permission = false, this.optedIn = false, this.id, this.token, this.linked = const {}});

  final bool permission;
  final bool optedIn;
  final String? id;
  final String? token;

  /// The addresses the mail server has confirmed it pushes to this phone.
  final Set<String> linked;

  bool get registered => (id ?? '').isNotEmpty && (token ?? '').isNotEmpty;
  bool get on => permission && optedIn && registered;
}

/// The phone signs in to OneSignal with a device id that survives reinstalls, then tells each worker which of its
/// addresses are on this phone, so mail is pushed to the phone (one subscription) and only for its own mailboxes.
abstract final class PushService {
  static const pushIdsKey = 'push_ids';
  static const optedInKey = 'push_opted_in';
  static const linkedKey = 'push_linked';
  static const _native = MethodChannel('quirepost/notifications');
  static final events = StreamController<PushEvent>.broadcast();
  static final changes = StreamController<PushStatus>.broadcast();
  static PushEvent? pendingOpen;
  static List<Account> _accounts = const [];
  static Set<String> _linked = const {};
  static Future<String>? _device;
  static String? _sentSubscription;

  static PushStatus get status => PushStatus(
    permission: OneSignal.Notifications.permission,
    optedIn: OneSignal.User.pushSubscription.optedIn ?? false,
    id: OneSignal.User.pushSubscription.id,
    token: OneSignal.User.pushSubscription.token,
    linked: _linked,
  );

  static Future<String> deviceId() => _device ??= _readDeviceId();

  static Future<String> _readDeviceId() async {
    try {
      final id = await _native.invokeMethod<String>('deviceId');
      if (id != null) return id;
    } catch (_) {}
    const storage = FlutterSecureStorage();
    try {
      final saved = await storage.read(key: 'device_id');
      if (saved != null) return saved;
      final id = 'device-${const Uuid().v4()}';
      await storage.write(key: 'device_id', value: id);
      return id;
    } catch (_) {
      return 'device-${const Uuid().v4()}';
    }
  }

  static Future<void> init() async {
    _linked = {...?(await SharedPreferences.getInstance()).getStringList(linkedKey)};
    OneSignal.initialize(AppConfig.oneSignalAppId).then((_) async {
      try {
        await OneSignal.login(await deviceId());
      } catch (_) {}
      await _changed();
    });
    OneSignal.Notifications.addClickListener((e) => _emit(_fromNotification(e.notification, opened: true)));
    OneSignal.Notifications.addForegroundWillDisplayListener((e) {
      if (e.notification.additionalData?['kind'] == 'test') return;
      e.preventDefault();
      _emit(_fromNotification(e.notification, opened: false));
    });
    OneSignal.Notifications.addPermissionObserver((_) => _changed());
    OneSignal.User.pushSubscription.addObserver((_) => _changed());
    _native.setMethodCallHandler((call) async {
      if (call.method == 'launch') _emit(_fromLaunch(call.arguments as Map));
    });
    try {
      final launch = await _native.invokeMapMethod<String, Object?>('takeLaunch');
      if (launch != null) pendingOpen = _fromLaunch(launch);
    } on MissingPluginException {
      return;
    }
  }

  static PushEvent _fromNotification(OSNotification n, {required bool opened}) {
    final data = n.additionalData ?? const <String, dynamic>{};
    final lines = (data['lines'] as List?)?.whereType<Map>().toList() ?? const [];
    final latest = lines.isEmpty ? null : lines.last;
    final mail = data['kind'] == 'mail';
    return PushEvent(
      host: data['host'] as String?,
      threadId: mail || data['kind'] == 'reaction' ? data['threadId'] as String? : null,
      messageId: mail ? data['messageId'] as String? : null,
      sender: latest?['from'] as String? ?? n.title,
      subject: data['subject'] as String? ?? n.body,
      snippet: latest?['text'] as String?,
      account: data['account'] as String?,
      quiet: data['quiet'] == 1,
      opened: opened,
    );
  }

  static PushEvent _fromLaunch(Map launch) => PushEvent(
    host: launch['host'] as String?,
    account: launch['account'] as String?,
    threadId: launch['threadId'] as String?,
    messageId: launch['messageId'] as String?,
    action: launch['action'] == 'reply' ? PushAction.reply : PushAction.open,
    text: launch['text'] as String?,
    opened: true,
  );

  static Future<void> _emit(PushEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    if (event.messageId != null) {
      final ids = [...prefs.getStringList(pushIdsKey) ?? <String>[], event.messageId!];
      await prefs.setStringList(pushIdsKey, ids.length > 300 ? ids.sublist(ids.length - 300) : ids);
    }
    if (event.opened && !events.hasListener) pendingOpen = event;
    events.add(event);
  }

  static void open(PushEvent e) =>
      events.add(PushEvent(host: e.host, account: e.account, threadId: e.threadId, messageId: e.messageId, opened: true));

  static Future<void> _changed() async {
    final now = status;
    await (await SharedPreferences.getInstance()).setBool(optedInKey, now.on);
    changes.add(now);
    if (now.id != null && now.id != _sentSubscription) await register(_accounts);
  }

  /// Asks for permission (offering the system settings when it was denied before) and opts the device back in.
  static Future<bool> enable() async {
    if (!OneSignal.Notifications.permission) await OneSignal.Notifications.requestPermission(true);
    if (OneSignal.Notifications.permission && OneSignal.User.pushSubscription.optedIn != true) {
      await OneSignal.User.pushSubscription.optIn();
    }
    await _changed();
    return OneSignal.Notifications.permission;
  }

  static Future<void> disable() async {
    await OneSignal.User.pushSubscription.optOut();
    await _changed();
  }

  static Future<void> chime() async {
    try {
      await _native.invokeMethod('chime');
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> clearFor(String account) async {
    try {
      await OneSignal.Notifications.removeGroupedNotifications(account);
    } catch (_) {}
  }

  /// Tells each worker which of its addresses are on this phone; [removed] clears a worker left with none.
  /// Sending the live subscription lets the worker delete the ones left behind by earlier installs.
  static Future<void> register(List<Account> accounts, {Account? removed}) async {
    _accounts = accounts;
    final device = await deviceId();
    final subscription = OneSignal.User.pushSubscription.id;
    if ((subscription ?? '').isNotEmpty) _sentSubscription = subscription;
    final workers = <String, (String, Set<String>)>{if (removed != null) removed.workerUrl: (removed.apiKey, <String>{})};
    for (final a in accounts) {
      (workers[a.workerUrl] ??= (a.apiKey, <String>{})).$2.add(a.email.toLowerCase());
    }
    final linked = <String>{};
    for (final MapEntry(key: url, value: (key, addresses)) in workers.entries) {
      try {
        linked.addAll(await ApiClient(url, key).registerDevice(device, addresses, subscriptionId: subscription));
      } catch (_) {
        linked.addAll(addresses.where(_linked.contains));
      }
    }
    _linked = linked;
    await (await SharedPreferences.getInstance()).setStringList(linkedKey, [...linked]);
    changes.add(status);
  }
}
