import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../accounts/accounts_repository.dart';
import '../core/api/api_client.dart';
import '../mail/models.dart' show Message;
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
  static const dailyKey = PushService.remindKey;
  static final notifications = FlutterLocalNotificationsPlugin();
  static final taps = StreamController<String?>.broadcast();
  static String? launchHost;
  static const _accent = Color(0xFF6750A4);
  static NotificationDetails _daily(String account, List<String> lines, String title) => NotificationDetails(
    android: AndroidNotificationDetails(
      'daily',
      'Daily reminder',
      channelDescription: 'A nudge once a day when unread mail is waiting',
      importance: Importance.defaultImportance,
      color: _accent,
      category: AndroidNotificationCategory.reminder,
      subText: account,
      visibility: NotificationVisibility.private,
      styleInformation: InboxStyleInformation(lines, htmlFormatLines: true, contentTitle: title, summaryText: account),
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: account),
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
    final linked = (prefs.getStringList(PushService.linkedKey) ?? const []).toSet();
    final today = '${now.year}-${now.month}-${now.day}';
    final daily = (prefs.getBool(dailyKey) ?? true) && now.hour >= 9 && prefs.getString(_lastDailyKey) != today;
    var reminded = false;

    for (final (i, account) in (await AccountsRepository().load()).indexed) {
      // The worker pushes, and reminds about, mail for the mailboxes it has linked to this phone.
      if (pushOn && linked.contains(account.email.toLowerCase())) continue;
      final page = await ApiClient(account.workerUrl, account.apiKey, mailbox: account.email).messages(unread: true);
      final unread = page.messages.where((m) => !m.outgoing).toList();
      if (daily && unread.isNotEmpty) {
        final title = '${unread.length} unread email${unread.length == 1 ? '' : 's'}';
        await notifications.show(
          id: 900 + i,
          title: title,
          body: unread.map((m) => m.from.display).toSet().take(3).join(', '),
          notificationDetails: _daily(account.email, [for (final m in unread.take(6)) _line(m)], title),
          payload: account.host,
        );
        reminded = true;
      }
      final fresh = unread.where((m) => m.date > lastCheck && !pushed.contains(m.id)).toList();
      if (fresh.isEmpty) continue;
      final senders = fresh.map((m) => m.from.display).toSet().take(3).join(', ');
      final title = '${fresh.length} new email${fresh.length == 1 ? '' : 's'}';
      await notifications.show(
        id: 1000 + i,
        title: title,
        body: senders,
        notificationDetails: _mail(account.email, [for (final m in fresh.take(6)) _line(m)], title),
        payload: account.host,
      );
    }

    if (reminded) await prefs.setString(_lastDailyKey, today);
    await prefs.setInt(_lastCheckKey, now.millisecondsSinceEpoch);
  }

  static String _line(Message m) => '<b>${_escape(m.from.display)}</b>  ${_escape(m.subject.isEmpty ? '(no subject)' : m.subject)}';

  static String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
