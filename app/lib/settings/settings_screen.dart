import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/accounts_controller.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/widgets.dart';
import '../core/quire/theme/metrics.dart';
import '../notifications/push_service.dart';
import '../notifications/push_status.dart';
import '../notifications/reminders.dart';
import 'settings_widgets.dart';

final catchAllProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.watch(apiProvider).catchAll());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final control = ref.read(settingsProvider.notifier);
    final state = ref.watch(accountsProvider).value;
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SettingsSection('Accounts'),
          for (final a in state?.accounts ?? [])
            SettingsRow(
              icon: LucideIcons.user,
              leading: Hero(
                tag: 'account-${a.id}',
                child: Avatar(name: a.name, size: 36),
              ),
              title: a.name,
              subtitle: a.email,
              trailing: state?.active?.id == a.id ? Icon(LucideIcons.circleCheck, size: 18, color: AppColors.accentBright) : null,
              onTap: () => context.push('/settings/account/${a.id}'),
            ),
          SettingsRow(icon: LucideIcons.userPlus, title: 'Add account', onTap: () => context.push('/onboarding?add=1')),
          const SettingsSection('Notifications'),
          const _Push(),
          SettingsRow(
            icon: LucideIcons.clock,
            title: 'Check for unread mail',
            subtitle: settings.reminderMinutes == 0 ? 'Off' : 'Every ${_interval(settings.reminderMinutes)}',
            onTap: () async {
              final minutes = await showQuireSheet<int>(
                context,
                (sheet) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetTitle('Check for unread mail'),
                    for (final m in const [0, 15, 30, 60, 120])
                      SheetRow(
                        label: m == 0 ? 'Off' : 'Every ${_interval(m)}',
                        selected: m == settings.reminderMinutes,
                        onTap: () => Navigator.pop(sheet, m),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
              if (minutes == null) return;
              await control.setReminderMinutes(minutes);
              await Reminders.schedule(minutes);
            },
          ),
          SettingsSwitch(
            icon: LucideIcons.sunrise,
            title: 'Daily reminder',
            subtitle: 'Once a day when unread mail is waiting',
            value: settings.dailyReminder,
            onChanged: control.setDailyReminder,
          ),
          const SettingsSection('Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: GooSegmented<ThemeMode>(
              values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labels: const ['System', 'Light', 'Dark'],
              selected: settings.themeMode,
              onChanged: (m) {
                Feel.turn.ring();
                control.setThemeMode(m);
              },
            ),
          ),
          const SettingsSection('Writing'),
          SettingsRow(icon: LucideIcons.signature, title: 'Signatures', onTap: () => context.push('/signatures')),
          SettingsSwitch(
            icon: LucideIcons.penLine,
            title: 'Add signature automatically',
            subtitle: 'On new emails and replies',
            value: settings.autoSignature,
            onChanged: control.setAutoSignature,
          ),
          SettingsRow(icon: LucideIcons.layoutTemplate, title: 'Templates', onTap: () => context.push('/templates')),
          const SettingsSection('Mail routing'),
          const _CatchAll(),
        ],
      ),
    );
  }

  static String _interval(int m) => m < 60 ? '$m minutes' : (m == 60 ? 'hour' : '${m ~/ 60} hours');
}

class _Push extends ConsumerStatefulWidget {
  const _Push();

  @override
  ConsumerState<_Push> createState() => _PushState();
}

class _PushState extends ConsumerState<_Push> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      if (on) {
        final granted = await PushService.enable();
        final state = ref.read(accountsProvider).value;
        if (granted && state != null) await PushService.syncTags(state.accounts, active: state.active);
      } else {
        await PushService.disable();
      }
      Feel.commit.ring();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test(String id) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).testPush(id);
      Feel.commit.ring();
      if (mounted) showToast(context, 'Sent. It should arrive in a few seconds');
    } catch (e) {
      if (!mounted) return;
      final unsubscribed = '$e'.contains('not subscribed');
      showToast(context, unsubscribed ? 'OneSignal does not see this phone as subscribed yet. Check the Firebase key in OneSignal.' : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final push = ref.watch(pushStatusProvider);
    final (detail, healthy) = switch (push) {
      PushStatus(permission: false) => ('Off. Allow notifications to hear about new mail', false),
      PushStatus(optedIn: false) => ('Paused on this phone', false),
      PushStatus(registered: false) => ('Allowed, waiting for a push ID from OneSignal', false),
      _ => ('On. New mail arrives with sound, grouped by account', true),
    };
    return Column(
      children: [
        SettingsRow(
          icon: LucideIcons.bell,
          leading: _StatusIcon(on: push.permission && push.optedIn, healthy: healthy),
          title: 'Push notifications',
          subtitle: detail,
          onTap: _busy ? null : () => _toggle(!(push.permission && push.optedIn)),
          trailing: Switch(
            value: push.permission && push.optedIn,
            onChanged: _busy
                ? null
                : (v) {
                    Feel.tap.ring();
                    _toggle(v);
                  },
          ),
        ),
        SettingsRow(
          icon: LucideIcons.send,
          title: 'Send a test notification',
          subtitle: push.registered ? 'Checks that new mail reaches this phone' : 'Available once this phone has a push ID',
          onTap: _busy || !push.registered ? null : () => _test(push.id!),
        ),
        SettingsRow(
          icon: LucideIcons.smartphone,
          title: 'Push ID',
          subtitle: push.id ?? 'Not assigned yet',
          trailing: push.id == null ? null : Icon(LucideIcons.copy, size: 18, color: AppColors.inkFaint),
          onTap: push.id == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: push.id!));
                  showToast(context, 'Push ID copied. Search for it in OneSignal, Audience.');
                },
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.on, required this.healthy});
  final bool on;
  final bool healthy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 22,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(on ? LucideIcons.bellRing : LucideIcons.bellOff, size: 22, color: AppColors.inkSoft),
        Positioned(
          right: -2,
          top: -2,
          child: AnimatedContainer(
            duration: kDim,
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: healthy ? const Color(0xFF21A366) : (on ? AppColors.found : AppColors.damage),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ground, width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CatchAll extends ConsumerStatefulWidget {
  const _CatchAll();

  @override
  ConsumerState<_CatchAll> createState() => _CatchAllState();
}

class _CatchAllState extends ConsumerState<_CatchAll> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).setCatchAll(on);
      Feel.commit.ring();
      ref.invalidate(catchAllProvider);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catchAllProvider);
    final on = state.value?['toWorker'] == true;
    return SettingsSwitch(
      icon: LucideIcons.inbox,
      title: 'Receive mail for every address',
      subtitle: switch (state) {
        AsyncError(:final error) => '$error',
        AsyncValue(hasValue: true) => on ? 'Any address on the domain lands here' : 'Only your sender addresses land here',
        _ => 'Checking',
      },
      value: on,
      onChanged: _busy || !state.hasValue ? null : _set,
    );
  }
}
