import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';
import 'notifications/push_service.dart';
import 'notifications/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Inter', 'Quicksand']) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('assets/fonts/OFL-$font.txt'));
    }
    yield const LicenseEntryWithLineBreaks(
      ['Noto Emoji Animation'],
      'Animated emoji by Google, https://googlefonts.github.io/noto-emoji-animation/\n'
      'Licensed under CC BY 4.0, https://creativecommons.org/licenses/by/4.0/legalcode',
    );
  });
  final prefs = await SharedPreferences.getInstance();
  await PushService.init();
  await Reminders.initNotifications(onTap: Reminders.taps.add);
  final launch = await Reminders.notifications.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp ?? false) Reminders.launchHost = launch!.notificationResponse?.payload;
  Reminders.schedule(prefs.getInt(SettingsController.reminderKey) ?? 30).ignore();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const App()));
}
