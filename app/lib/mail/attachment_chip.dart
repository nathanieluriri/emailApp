import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../accounts/accounts_controller.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/quire/widgets/quire_spinner.dart';
import '../core/widgets.dart';
import 'format.dart';
import 'models.dart';

class AttachmentChip extends ConsumerStatefulWidget {
  const AttachmentChip({super.key, required this.attachment});
  final Attachment attachment;

  @override
  ConsumerState<AttachmentChip> createState() => _AttachmentChipState();
}

class _AttachmentChipState extends ConsumerState<AttachmentChip> {
  bool _busy = false;

  Future<void> _open() async {
    final a = widget.attachment;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(apiProvider).attachment(a.id);
      if (!mounted) return;
      if (a.isImage) {
        await showQuireSheet(
          context,
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetTitle(a.filename),
                Flexible(
                  child: InteractiveViewer(
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes)),
                  ),
                ),
                const SizedBox(height: 12),
                PillButton(label: 'Open in another app', icon: LucideIcons.externalLink, onTap: () => _launch(a, bytes)),
              ],
            ),
          ),
        );
      } else {
        await _launch(a, bytes);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Could not open ${a.filename}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launch(Attachment a, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${a.id}-${a.filename.replaceAll(RegExp(r'[/\\]'), '_')}');
    await file.writeAsBytes(bytes);
    final result = await OpenFilex.open(file.path, type: a.mimeType);
    if (result.type != ResultType.done && mounted) showToast(context, result.message);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    return PaperPress(
      onTap: _busy ? null : _open,
      semanticLabel: 'Open ${a.filename}',
      washRadius: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _busy
                ? const QuireSpinner(size: 18)
                : Icon(a.isImage ? LucideIcons.image : LucideIcons.fileText, size: 18, color: AppColors.accentBright),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                a.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 6),
            Text(fileSize(a.size), style: AppText.docMeta.copyWith(color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
