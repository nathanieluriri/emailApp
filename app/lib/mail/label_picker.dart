import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'mail_providers.dart';
import 'mail_repository.dart';
import 'models.dart';

/// Pick which labels a message carries. Pops with the new label ids.
Future<List<String>?> pickLabels(BuildContext context, List<String> current) =>
    showQuireSheet<List<String>>(context, (context) => _LabelPicker(current: current));

class _LabelPicker extends ConsumerStatefulWidget {
  const _LabelPicker({required this.current});
  final List<String> current;

  @override
  ConsumerState<_LabelPicker> createState() => _LabelPickerState();
}

class _LabelPickerState extends ConsumerState<_LabelPicker> {
  late final _chosen = {...widget.current};

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(labelsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetTitle('Label as'),
        Flexible(
          child: labels.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Loader()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(20), child: Text('$e')),
            data: (list) => ListView(
              shrinkWrap: true,
              children: [
                for (final l in list.where((l) => l.id != 'sent'))
                  SheetRow(
                    label: l.name,
                    icon: LucideIcons.tag,
                    onTap: () => setState(() => _chosen.contains(l.id) ? _chosen.remove(l.id) : _chosen.add(l.id)),
                    trailing: Checkbox(
                      value: _chosen.contains(l.id),
                      activeColor: AppColors.accent,
                      onChanged: (v) => setState(() => v! ? _chosen.add(l.id) : _chosen.remove(l.id)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerRight,
            child: PillButton(label: 'Apply', onTap: () => Navigator.pop(context, _chosen.toList())),
          ),
        ),
      ],
    );
  }
}

/// Create, rename, recolour and delete labels.
class LabelsManager extends ConsumerWidget {
  const LabelsManager({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [MailLabel? label]) async {
    final name = await promptText(context, title: label == null ? 'New label' : 'Rename label', initial: label?.name ?? '');
    if (name == null || name.isEmpty || !context.mounted) return;
    final api = ref.read(mailRepositoryProvider).api;
    try {
      label == null ? await api.createLabel(name, toHex(AppColors.labelColors.first)) : await api.updateLabel(label.id, name: name);
      ref.invalidate(labelsProvider);
    } catch (e) {
      if (context.mounted) showToast(context, '$e');
    }
  }

  Future<void> _color(BuildContext context, WidgetRef ref, MailLabel label) async {
    final color = await showQuireSheet<Color>(
      context,
      (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetTitle('Colour'),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final c in AppColors.labelColors)
                  PaperPress(
                    onTap: () => Navigator.pop(context, c),
                    washRadius: 22,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (color == null) return;
    try {
      await ref.read(mailRepositoryProvider).api.updateLabel(label.id, color: toHex(color));
      ref.invalidate(labelsProvider);
    } catch (e) {
      if (context.mounted) showToast(context, '$e');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, MailLabel label) async {
    if (!await confirm(context, title: 'Delete "${label.name}"?', action: 'Delete label', body: 'Mail keeps its other labels.')) return;
    try {
      await ref.read(mailRepositoryProvider).api.deleteLabel(label.id);
      ref.invalidate(labelsProvider);
    } catch (e) {
      if (context.mounted) showToast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetTitle('Labels'),
        Flexible(
          child: labels.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Loader()),
            error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(labelsProvider)),
            data: (list) => ListView(
              shrinkWrap: true,
              children: [
                for (final l in list.where((l) => !l.system))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        PaperPress(
                          onTap: () => _color(context, ref, l),
                          washRadius: 20,
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(LucideIcons.tag, color: parseHex(l.color, AppColors.inkSoft), fill: 1),
                          ),
                        ),
                        Expanded(
                          child: Text(l.name, style: AppText.menuRow.copyWith(color: AppColors.ink)),
                        ),
                        IconPress(icon: LucideIcons.pencil, label: 'Rename', size: 18, onTap: () => _edit(context, ref, l)),
                        IconPress(
                          icon: LucideIcons.trash2,
                          label: 'Delete',
                          size: 18,
                          color: AppColors.damage,
                          onTap: () => _delete(context, ref, l),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SheetRow(
          label: 'Create new label',
          icon: LucideIcons.plus,
          onTap: () {
            Feel.tap.ring();
            _edit(context, ref);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
