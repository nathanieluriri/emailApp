import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/account.dart';
import '../accounts/accounts_controller.dart';
import '../accounts/health_check.dart';
import '../core/api/api_client.dart';
import '../core/motion.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import '../notifications/push_service.dart';
import '../notifications/reminders.dart';

final catchAllProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.watch(apiProvider).catchAll());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Text(text, style: AppText.sortLabel.copyWith(color: AppColors.accentBright)),
  );

  Future<void> _retest(BuildContext context, Account a) async {
    final report = await checkWorker(a.workerUrl);
    String? keyError;
    try {
      await ApiClient(a.workerUrl, a.apiKey).senders();
    } catch (e) {
      keyError = '${ApiException.from(e)}';
    }
    if (!context.mounted) return;
    report.ok && keyError == null ? Feel.commit.ring() : Feel.turn.ring();
    showQuireSheet(
      context,
      (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetTitle(a.nickname),
            Text(
              keyError == null ? 'API key accepted' : 'API key: $keyError',
              style: AppText.bodyTight.copyWith(color: keyError == null ? AppColors.inkSoft : AppColors.damage),
            ),
            const SizedBox(height: 10),
            HealthChecklist(report: report),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final control = ref.read(settingsProvider.notifier);
    final state = ref.watch(accountsProvider).value;
    final accounts = ref.read(accountsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _section('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GooSegmented<ThemeMode>(
              values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labels: const ['System', 'Light', 'Dark'],
              selected: settings.themeMode,
              onChanged: control.setThemeMode,
            ),
          ),
          _section('Accounts'),
          for (final (i, a) in (state?.accounts ?? <Account>[]).indexed)
            EntryMotion(
              index: i,
              child: PaperPress(
                feel: Feel.turn,
                onTap: () => accounts.switchTo(a.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      Avatar(name: a.nickname),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(a.nickname, style: AppText.rowTitle.copyWith(color: AppColors.ink)),
                                ),
                                if (state?.active?.id == a.id) ...[
                                  const SizedBox(width: 8),
                                  Icon(LucideIcons.circleCheck, size: 16, color: AppColors.accentBright),
                                ],
                              ],
                            ),
                            Text(a.host, style: AppText.docMeta.copyWith(color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                      IconPress(icon: LucideIcons.activity, label: 'Test again', size: 18, onTap: () => _retest(context, a)),
                      IconPress(
                        icon: LucideIcons.pencil,
                        label: 'Rename',
                        size: 18,
                        onTap: () async {
                          final name = await promptText(context, title: 'Rename account', initial: a.nickname);
                          if (name != null && name.isNotEmpty) await accounts.replace(a.copyWith(nickname: name));
                        },
                      ),
                      IconPress(
                        icon: LucideIcons.trash2,
                        label: 'Remove',
                        size: 18,
                        color: AppColors.damage,
                        onTap: () async {
                          if (!await confirm(
                            context,
                            title: 'Remove ${a.nickname}?',
                            action: 'Remove account',
                            body: 'Saved mail and drafts for it are cleared from this phone.',
                          )) {
                            return;
                          }
                          await accounts.remove(a.id);
                          if (context.mounted && (ref.read(accountsProvider).value?.accounts.isEmpty ?? true)) context.go('/onboarding');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SheetRow(label: 'Add account', icon: LucideIcons.userPlus, onTap: () => context.push('/onboarding?add=1')),
          _section('Notifications'),
          SheetRow(
            label: PushService.permitted ? 'Push notifications are on' : 'Turn on push notifications',
            icon: LucideIcons.bell,
            onTap: PushService.permitted
                ? null
                : () async {
                    await PushService.requestPermission();
                    if (state != null) await PushService.syncTags(state.accounts, active: state.active);
                  },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text('Check for unread mail', style: AppText.label.copyWith(color: AppColors.inkSoft)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GooSegmented<int>(
              values: const [0, 15, 30, 60, 120],
              labels: const ['Off', '15m', '30m', '1h', '2h'],
              selected: settings.reminderMinutes,
              onChanged: (m) async {
                await control.setReminderMinutes(m);
                await Reminders.schedule(m);
              },
            ),
          ),
          SwitchListTile(
            value: settings.dailyReminder,
            title: Text('Daily reminder for unread mail', style: AppText.rowTitle.copyWith(color: AppColors.ink)),
            onChanged: (v) {
              Feel.tap.ring();
              control.setDailyReminder(v);
            },
          ),
          _section('Writing'),
          SwitchListTile(
            value: settings.autoSignature,
            title: Text('Add signature automatically', style: AppText.rowTitle.copyWith(color: AppColors.ink)),
            onChanged: (v) {
              Feel.tap.ring();
              control.setAutoSignature(v);
            },
          ),
          SheetRow(label: 'Signatures', icon: LucideIcons.signature, onTap: () => context.push('/signatures')),
          SheetRow(label: 'Templates', icon: LucideIcons.layoutTemplate, onTap: () => context.push('/templates')),
          _section('Mail routing'),
          const _CatchAll(),
        ],
      ),
    );
  }
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
    return SwitchListTile(
      value: state.value?['toWorker'] == true,
      title: Text('Catch-all goes to this app', style: AppText.rowTitle.copyWith(color: AppColors.ink)),
      subtitle: Text(switch (state) {
        AsyncError(:final error) => '$error',
        AsyncValue(value: final v?) =>
          v['toWorker'] == true
              ? 'Mail to any address on the domain lands here. Turning it off restores the previous rule.'
              : 'Only the sender addresses land here. The domain\'s catch-all rule is left as it is.',
        _ => 'Checking',
      }, style: AppText.docMeta.copyWith(color: state.hasError ? AppColors.damage : AppColors.inkSoft)),
      onChanged: _busy || state.hasError || !state.hasValue ? null : _set,
    );
  }
}
