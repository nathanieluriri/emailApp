import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/health_check.dart';
import '../accounts/onboarding_screen.dart';
import '../core/api/api_client.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/widgets.dart';
import 'settings_widgets.dart';

/// Outlook's account page: who you are, how you appear, and where your mail lives.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, required this.accountId});
  final String accountId;

  Future<void> _test(BuildContext context, String url, String key) async {
    final report = await checkWorker(url);
    String? keyError;
    try {
      await ApiClient(url, key).senders();
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
            SheetTitle(report.ok && keyError == null ? 'Everything works' : 'Something needs attention'),
            Text(
              keyError == null ? 'Access key accepted' : 'Access key: $keyError',
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
    final accounts = ref.watch(accountsProvider).value?.accounts ?? [];
    final a = accounts.where((x) => x.id == accountId).firstOrNull;
    final control = ref.read(accountsProvider.notifier);
    if (a == null) return const Scaffold(body: SizedBox.shrink());
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Hero(
              tag: 'account-${a.id}',
              child: Avatar(name: a.name, size: 96),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(a.name, style: AppText.pageHeading2.copyWith(color: AppColors.ink)),
          ),
          Center(
            child: Text(a.email, style: AppText.bodyTight.copyWith(color: AppColors.inkSoft)),
          ),
          const SizedBox(height: 20),
          SettingsRow(
            icon: LucideIcons.userPen,
            title: 'Display name',
            subtitle: a.displayName,
            trailing: Icon(LucideIcons.pencil, size: 18, color: AppColors.inkSoft),
            onTap: () async {
              final name = await promptText(context, title: 'Display name', initial: a.displayName, hint: 'Shown next to your address');
              if (name != null && name.isNotEmpty) await control.replace(a.copyWith(displayName: name));
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SenderPreview(name: a.displayName, email: a.email),
          ),
          const SettingsSection('Connection'),
          SettingsRow(icon: LucideIcons.server, title: 'Server', subtitle: a.host),
          SettingsRow(icon: LucideIcons.activity, title: 'Test connection', onTap: () => _test(context, a.workerUrl, a.apiKey)),
          SettingsRow(
            icon: LucideIcons.keyRound,
            title: 'Replace access key',
            onTap: () async {
              final key = await promptText(context, title: 'New access key', action: 'Save key');
              if (key != null && key.isNotEmpty) await control.replace(a.copyWith(apiKey: key));
            },
          ),
          const SizedBox(height: 16),
          SettingsRow(
            icon: LucideIcons.logOut,
            title: 'Remove account',
            destructive: true,
            onTap: () async {
              if (!await confirm(
                context,
                title: 'Remove ${a.email}?',
                action: 'Remove account',
                body: 'Saved mail and drafts for it are cleared from this phone.',
              )) {
                return;
              }
              await control.remove(a.id);
              if (!context.mounted) return;
              (ref.read(accountsProvider).value?.accounts.isEmpty ?? true) ? context.go('/onboarding') : context.pop();
            },
          ),
        ],
      ),
    );
  }
}
