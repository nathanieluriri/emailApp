import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/metrics.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/digit_roll.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'mail_providers.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 12),
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

    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 20, 18),
              child: Row(
                children: [
                  Image.asset('assets/brand/quire-mark.png', width: 28, height: 28),
                  const SizedBox(width: 12),
                  Text('Bridgewood', style: AppText.wordmarkSmall.copyWith(color: AppColors.ink)),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 8),
            for (final e in systemLabels.entries)
              row(e.key, e.value, _icons[e.key]!, count: e.key == 'inbox' || e.key == 'spam' ? unread[e.key] ?? 0 : 0),
            if (labels.any((l) => !l.system)) heading('Labels'),
            for (final l in labels.where((l) => !l.system))
              row(l.id, l.name, LucideIcons.tag, tint: parseHex(l.color, AppColors.inkSoft), count: l.unread),
            heading('Write'),
            row('/drafts', 'Drafts', LucideIcons.file, onTap: () => onLink('/drafts')),
            row('/templates', 'Templates', LucideIcons.layoutTemplate, onTap: () => onLink('/templates')),
            row('/signatures', 'Signatures', LucideIcons.signature, onTap: () => onLink('/signatures')),
            row('/labels', 'Manage labels', LucideIcons.tags, onTap: () => onLink('/labels')),
            row('/settings', 'Settings', LucideIcons.settings, onTap: () => onLink('/settings')),
          ],
        ),
      ),
    );
  }
}
