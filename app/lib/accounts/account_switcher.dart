import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/motion.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'accounts_controller.dart';

void showAccountSwitcher(BuildContext context) => showQuireSheet(context, (_) => const _Switcher());

class _Switcher extends ConsumerWidget {
  const _Switcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountsProvider).value;
    final accounts = state?.accounts ?? [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, a) in accounts.indexed)
          EntryMotion(
            index: i,
            child: PaperPress(
              feel: Feel.turn,
              onTap: () async {
                await ref.read(accountsProvider.notifier).switchTo(a.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Avatar(name: a.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: AppText.rowTitle.copyWith(color: AppColors.ink)),
                          Text(a.email, style: AppText.docMeta.copyWith(color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    AnimatedScale(
                      scale: state?.active?.id == a.id ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Icon(LucideIcons.circleCheck, color: AppColors.accentBright),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Divider(height: 16, color: AppColors.hairline),
        SheetRow(
          label: 'Add an account',
          icon: LucideIcons.userPlus,
          onTap: () {
            Navigator.pop(context);
            context.push('/onboarding?add=1');
          },
        ),
        SheetRow(
          label: 'Manage accounts',
          icon: LucideIcons.settings,
          onTap: () {
            Navigator.pop(context);
            context.push('/settings');
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
