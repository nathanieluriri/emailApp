import 'package:flutter/material.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
    child: Text(title, style: AppText.label.copyWith(color: AppColors.accentBright)),
  );
}

/// A settings line: icon, title, optional detail, optional trailing control.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.leading,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.damage : AppColors.ink;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          leading ?? Icon(icon, size: 22, color: destructive ? AppColors.damage : AppColors.inkSoft),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.rowTitle.copyWith(color: color)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return PaperPress(onTap: onTap, feel: destructive ? Feel.commit : Feel.tap, semanticLabel: title, child: row);
  }
}

class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({super.key, required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: Switch(
      value: value,
      onChanged: onChanged == null
          ? null
          : (v) {
              Feel.tap.ring();
              onChanged!(v);
            },
    ),
  );
}
