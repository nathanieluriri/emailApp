import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../accounts/accounts_repository.dart';
import '../core/api/api_client.dart';
import 'push_service.dart';

@pragma('vm:entry-point')
void reminderDispatcher() {
  Workmanager().executeTask((task, data) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Reminders.check();
    } catch (_) {}
    return true;
  });
}

abstract final class Reminders {
  static const _task = 'unread-check';
  static const _lastCheckKey = 'reminder_last_check';
  static const _lastDailyKey = 'reminder_last_daily';
  static const dailyKey = 'daily_reminder';
  static final notifications = FlutterLocalNotificationsPlugin();
  static final taps = StreamController<String?>.broadcast();
  static String? launchHost;
  static const _accent = Color(0xFF6750A4);
  static const _daily = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'A gentle nudge when unread mail is waiting',
      importance: Importance.low,
      color: _accent,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static NotificationDetails _mail(String account, List<String> lines, String title) => NotificationDetails(
    android: AndroidNotificationDetails(
      'mail',
      'New mail',
      channelDescription: 'Every new email as it arrives',
      importance: Importance.high,
      priority: Priority.high,
      color: _accent,
      category: AndroidNotificationCategory.email,
      subText: account,
      visibility: NotificationVisibility.private,
      styleInformation: InboxStyleInformation(lines, htmlFormatLines: true, contentTitle: title, summaryText: account),
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: account),
  );

  static Future<void> initNotifications({void Function(String? payload)? onTap}) => notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_onesignal_default'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ),
    onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
  );

  static Future<void> schedule(int minutes) async {
    await Workmanager().initialize(reminderDispatcher);
    if (minutes <= 0) return Workmanager().cancelByUniqueName(_task);
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: Duration(minutes: minutes < 15 ? 15 : minutes),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> check() async {
    final prefs = await SharedPreferences.getInstance();
    await initNotifications();
    final now = DateTime.now();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? now.millisecondsSinceEpoch;
    final pushed = (prefs.getStringList(PushService.pushIdsKey) ?? []).toSet();
    final pushOn = prefs.getBool(PushService.optedInKey) ?? false;
    var unreadTotal = 0;

    for (final (i, account) in (await AccountsRepository().load()).indexed) {
      final page = await ApiClient(account.workerUrl, account.apiKey, mailbox: account.email).messages(unread: true);
      unreadTotal += page.messages.length;
      final fresh = page.messages.where((m) => m.date > lastCheck && !pushed.contains(m.id)).toList();
      if (fresh.isEmpty || pushOn) continue;
      final senders = fresh.map((m) => m.from.display).toSet().take(3).join(', ');
      final title = '${fresh.length} new email${fresh.length == 1 ? '' : 's'}';
      await notifications.show(
        id: 1000 + i,
        title: title,
        body: senders,
        notificationDetails: _mail(
          account.email,
          [for (final m in fresh.take(6)) '<b>${_escape(m.from.display)}</b>  ${_escape(m.subject)}'],
          title,
        ),
        payload: account.host,
      );
    }

    final today = '${now.year}-${now.month}-${now.day}';
    if ((prefs.getBool(dailyKey) ?? true) && unreadTotal > 0 && now.hour >= 9 && prefs.getString(_lastDailyKey) != today) {
      await prefs.setString(_lastDailyKey, today);
      await notifications.show(
        id: 999,
        title: 'Mail is waiting',
        body: '$unreadTotal unread email${unreadTotal == 1 ? ' is' : 's are'} waiting for you',
        notificationDetails: _daily,
      );
    }
    await prefs.setInt(_lastCheckKey, now.millisecondsSinceEpoch);
  }

  static String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
