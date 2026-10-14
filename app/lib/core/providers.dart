import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('overridden in main'));

class Settings {
  const Settings({required this.themeMode, required this.autoSignature, required this.reminderMinutes, required this.dailyReminder});
  final ThemeMode themeMode;
  final bool autoSignature;
  final int reminderMinutes;
  final bool dailyReminder;
}

class SettingsController extends Notifier<Settings> {
  static const themeKey = 'theme_mode';
  static const autoSignatureKey = 'auto_signature';
  static const reminderKey = 'reminder_minutes';
  static const dailyKey = 'daily_reminder';

  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  Settings build() => Settings(
    themeMode: ThemeMode.values[_prefs.getInt(themeKey) ?? ThemeMode.system.index],
    autoSignature: _prefs.getBool(autoSignatureKey) ?? true,
    reminderMinutes: _prefs.getInt(reminderKey) ?? 30,
    dailyReminder: _prefs.getBool(dailyKey) ?? true,
  );

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(themeKey, mode.index);
    ref.invalidateSelf();
  }

  Future<void> setAutoSignature(bool on) async {
    await _prefs.setBool(autoSignatureKey, on);
    ref.invalidateSelf();
  }

  Future<void> setReminderMinutes(int minutes) async {
    await _prefs.setInt(reminderKey, minutes);
    ref.invalidateSelf();
  }

  Future<void> setDailyReminder(bool on) async {
    await _prefs.setBool(dailyKey, on);
    ref.invalidateSelf();
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(SettingsController.new);
