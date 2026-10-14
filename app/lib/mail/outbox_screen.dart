import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/accounts_controller.dart';
import '../compose/compose_args.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/typography.dart';
import '../core/widgets.dart';
import 'format.dart';
import 'outbox.dart';
import 'quote.dart';

/// What is waiting to leave this mailbox, oldest first: Gmail's Outbox.
class OutboxScreen extends ConsumerWidget {
  const OutboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final items = ref.watch(outboxProvider).where((q) => q.accountId == account?.id).toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
        title: const Text('Outbox'),
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: LucideIcons.mailClock,
              title: 'Nothing waiting',
              body: 'Mail you send waits here while there is no connection, and leaves on its own when it is back.',
            )
          : ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              children: [for (final q in items) QueuedCard(key: ValueKey(q.id), item: q, showSubject: true)],
            ),
    );
  }
}

/// A message still in the outbox, shown where the sent one will be: in its thread, or in the Outbox. Its status sits
/// where a sent message shows its time.
class QueuedCard extends ConsumerWidget {
  const QueuedCard({super.key, required this.item, this.showSubject = false});
  final Queued item;
  final bool showSubject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbox = ref.watch(outboxProvider.notifier);
    ref.watch(outboxProvider);
    final waiting = item.attempts > 0 && !item.held && !outbox.isSending(item.id);
    final (status, tint) = item.held
        ? ('Not sent', AppColors.damage)
        : waiting
        ? ('Queued', AppColors.damage)
        : ('Sending…', AppColors.inkSoft);
    final meta = AppText.bodyTight.copyWith(color: AppColors.inkSoft, fontSize: 14);
    final created = DateTime.fromMillisecondsSinceEpoch(item.createdAt);
    final from = '${item.body['fromName'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(name: from.isEmpty ? '${item.body['from']}' : from, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Me',
                      style: AppText.rowTitle.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 17),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        DateUtils.isSameDay(created, DateTime.now()) ? status : '$status · ${shortDate(created)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: meta.copyWith(color: tint, fontWeight: tint == AppColors.damage ? FontWeight.w600 : null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('to ${item.to.join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
                if (showSubject && item.subject.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyTight.copyWith(color: AppColors.ink),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  splitQuotedText(item.text).$1,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.pageBody.copyWith(color: AppColors.ink, height: 1.4),
                ),
                if (item.held || waiting) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.held ? item.error ?? 'The server turned it down' : 'Sends when the connection is back',
                    style: AppText.docMeta.copyWith(color: item.held ? AppColors.damage : AppColors.inkSoft),
                  ),
                ],
              ],
            ),
          ),
          IconPress(icon: LucideIcons.ellipsisVertical, label: 'More', size: 22, onTap: () => _actions(context, ref)),
        ],
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final outbox = ref.read(outboxProvider.notifier);
    final db = ref.read(databaseProvider);
    final router = GoRouter.of(context);
    final picked = await showQuireSheet<int>(
      context,
      (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetTitle(item.subject.isEmpty ? '(no subject)' : item.subject),
          SheetRow(label: 'Send now', icon: LucideIcons.send, onTap: () => Navigator.pop(sheet, 0)),
          SheetRow(label: 'Edit', icon: LucideIcons.pencil, onTap: () => Navigator.pop(sheet, 1)),
          SheetRow(label: 'Delete', icon: LucideIcons.trash2, destructive: true, onTap: () => Navigator.pop(sheet, 2)),
          const SizedBox(height: 8),
        ],
      ),
    );
    switch (picked) {
      case 0:
        await outbox.retry(item.id);
      case 1:
        final back = await outbox.take(item.id);
        final draft = back?.draft;
        final draftId = back?.draftId;
        if (back == null || draft == null || draftId == null) return;
        await db.putDraft(draftId, back.accountId, draft);
        router.push(
          '/compose',
          extra: ComposeArgs(draftId: draftId, attachments: back.attachments, threadId: back.threadId),
        );
      case 2:
        await outbox.take(item.id);
    }
  }
}
