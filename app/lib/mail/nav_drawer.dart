import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/accounts_controller.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/metrics.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/digit_roll.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'mail_providers.dart';
import 'outbox.dart';
import '../compose/drafts_screen.dart';

const _icons = {
  'inbox': LucideIcons.inbox,
  'starred': LucideIcons.star,
  'sent': LucideIcons.send,
  'all': LucideIcons.mails,
  'spam': LucideIcons.octagonAlert,
  'trash': LucideIcons.trash2,
};

class NavDrawer extends ConsumerWidget {
  const NavDrawer({super.key, required this.selected, required this.onSelect, required this.onLink});
  final String selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider).value ?? [];
    final unread = {for (final l in labels) l.id: l.unread};
    Widget row(String id, String name, IconData icon, {Color? tint, int count = 0, VoidCallback? onTap}) {
      final on = id == selected;
      return Padding(
        padding: const EdgeInsets.only(left: 8, right: 12),
        child: PaperPress(
          onTap: onTap ?? () => onSelect(id),
          semanticLabel: name,
          washRadius: kDrawerRowRadius,
          child: AnimatedContainer(
            duration: kDim,
            height: kDrawerRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: kDrawerRowPaddingX),
            decoration: BoxDecoration(
              color: on ? AppColors.accentMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(kDrawerRowRadius),
            ),
            child: Row(
              children: [
                Icon(icon, size: kDrawerRowGlyph, color: tint ?? AppColors.ink, fill: tint != null ? 1 : 0),
                const SizedBox(width: kDrawerRowGap),
                Expanded(
                  child: Text(name, style: (on ? AppText.drawerRowSelected : AppText.drawerRow).copyWith(color: AppColors.ink)),
                ),
                if (count > 0) DigitRoll(count > 99 ? '99+' : '$count', style: AppText.label, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      );
    }

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
      child: Text(text, style: AppText.label.copyWith(color: AppColors.inkSoft)),
    );

    final accounts = ref.watch(accountsProvider).value;
    final active = accounts?.active;
    final queued = ref.watch(outboxProvider).where((q) => q.accountId == active?.id).length;
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        right: false,
        child: Row(
          children: [
            Container(
              width: 68,
              color: AppColors.ground.withValues(alpha: 0.5),
              child: Column(
                children: [
                  const SizedBox(height: 64),
                  for (final a in accounts?.accounts ?? [])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: PaperPress(
                        feel: Feel.turn,
                        semanticLabel: 'Switch to ${a.email}',
                        washRadius: 24,
                        onTap: () => ref.read(accountsProvider.notifier).switchTo(a.id),
                        child: AnimatedContainer(
                          duration: kDim,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: a.id == active?.id ? AppColors.accentBright : Colors.transparent, width: 2),
                          ),
                          child: Avatar(name: a.name, size: 38),
                        ),
                      ),
                    ),
                  IconPress(
                    icon: LucideIcons.plus,
                    label: 'Add account',
                    color: AppColors.inkSoft,
                    onTap: () => onLink('/onboarding?add=1'),
                  ),
                  const Spacer(),
                  IconPress(icon: LucideIcons.settings, label: 'Settings', color: AppColors.inkSoft, onTap: () => onLink('/settings')),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 18, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active?.name ?? 'Mail',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title.copyWith(color: AppColors.ink),
                        ),
                        Text(
                          active?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  for (final e in systemLabels.entries)
                    row(e.key, e.value, _icons[e.key]!, count: e.key == 'inbox' || e.key == 'spam' ? unread[e.key] ?? 0 : 0),
                  if (queued > 0) row('/outbox', 'Outbox', LucideIcons.mailClock, count: queued, onTap: () => onLink('/outbox')),
                  row(
                    '/drafts',
                    'Drafts',
                    LucideIcons.file,
                    count: ref.watch(draftsProvider).value?.length ?? 0,
                    onTap: () => onLink('/drafts'),
                  ),
                  if (labels.any((l) => !l.system)) heading('Labels'),
                  for (final l in labels.where((l) => !l.system))
                    row(l.id, l.name, LucideIcons.tag, tint: parseHex(l.color, AppColors.inkSoft), count: l.unread),
                  row('/labels', 'Manage labels', LucideIcons.tags, onTap: () => onLink('/labels')),
                  heading('Tools'),
                  row('/templates', 'Templates', LucideIcons.layoutTemplate, onTap: () => onLink('/templates')),
                  row('/signatures', 'Signatures', LucideIcons.signature, onTap: () => onLink('/signatures')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
