import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../compose/compose_args.dart';
import '../core/motion.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'attachment_chip.dart';
import 'format.dart';
import 'html_view.dart';
import 'label_picker.dart';
import 'mail_providers.dart';
import 'mail_repository.dart';
import 'models.dart';

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId, this.heroMessageId});
  final String threadId;
  final String? heroMessageId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _expanded = <String>{};
  bool _markedRead = false;

  void _markRead(MailThread t) {
    if (_markedRead) return;
    _markedRead = true;
    final api = ref.read(mailRepositoryProvider).api;
    final inbox = ref.read(inboxProvider(ref.read(currentLabelProvider)).notifier);
    for (final m in t.messages.where((m) => !m.read)) {
      api.updateMessage(m.id, read: true).ignore();
      inbox.markRead(m.id);
    }
  }

  Future<void> _act(String done, Future<void> Function() action, {bool leave = true}) async {
    Feel.commit.ring();
    try {
      await action();
      ref.invalidate(inboxProvider);
      ref.invalidate(labelsProvider);
      if (!mounted) return;
      showToast(context, done);
      if (leave) context.pop();
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  Future<void> _each(MailThread t, Future<void> Function(Message m) action) => Future.wait(t.messages.map(action));

  void _compose(ComposeKind kind, Message m) => context.push(
    '/compose',
    extra: ComposeArgs(kind: kind, source: m),
  );

  void _menu(MailThread t) {
    final api = ref.read(mailRepositoryProvider).api;
    final last = t.messages.last;
    showQuireSheet(
      context,
      (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetRow(
            label: 'Label as',
            icon: LucideIcons.tag,
            onTap: () async {
              Navigator.pop(sheet);
              final labels = await pickLabels(context, last.labels);
              if (labels != null) {
                await _act('Labels updated', () => _each(t, (m) => api.updateMessage(m.id, labels: labels)), leave: false);
              }
            },
          ),
          SheetRow(
            label: last.starred ? 'Remove star' : 'Add star',
            icon: LucideIcons.star,
            onTap: () {
              Navigator.pop(sheet);
              _act(
                last.starred ? 'Star removed' : 'Starred',
                () => api.updateMessage(last.id, starred: !last.starred),
                leave: false,
              ).then((_) => ref.invalidate(threadProvider(widget.threadId)));
            },
          ),
          SheetRow(
            label: 'Mark unread',
            icon: LucideIcons.mailOpen,
            onTap: () {
              Navigator.pop(sheet);
              _act('Marked unread', () => api.updateMessage(last.id, read: false));
            },
          ),
          SheetRow(
            label: 'Forward',
            icon: LucideIcons.forward,
            onTap: () {
              Navigator.pop(sheet);
              _compose(ComposeKind.forward, last);
            },
          ),
          if (last.labels.contains('spam'))
            SheetRow(
              label: 'Report not spam',
              icon: LucideIcons.shieldCheck,
              onTap: () {
                Navigator.pop(sheet);
                _act('Moved to Inbox', () => _each(t, (m) => api.updateMessage(m.id, labels: ['inbox'])));
              },
            )
          else
            SheetRow(
              label: 'Report spam',
              icon: LucideIcons.octagonAlert,
              destructive: true,
              onTap: () {
                Navigator.pop(sheet);
                _act('Moved to Spam', () => _each(t, (m) => api.updateMessage(m.id, labels: ['spam'])));
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(threadProvider(widget.threadId));
    final t = thread.value;
    final api = ref.read(mailRepositoryProvider).api;
    if (t != null) WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(t));
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
        actions: t == null
            ? null
            : [
                IconPress(
                  icon: LucideIcons.archive,
                  label: 'Archive',
                  onTap: () => _act('Archived', () => _each(t, (m) => api.updateMessage(m.id, archived: true))),
                ),
                IconPress(
                  icon: LucideIcons.trash2,
                  label: 'Delete',
                  onTap: () => _act('Moved to Trash', () => _each(t, (m) => api.updateMessage(m.id, labels: ['trash']))),
                ),
                IconPress(
                  icon: LucideIcons.mail,
                  label: 'Mark unread',
                  onTap: () => _act('Marked unread', () => api.updateMessage(t.messages.last.id, read: false)),
                ),
                IconPress(icon: LucideIcons.ellipsisVertical, label: 'More', onTap: () => _menu(t)),
              ],
      ),
      body: switch (thread) {
        AsyncValue(value: final t?) => _body(t),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(threadProvider(widget.threadId))),
        _ => const Loader(),
      },
      bottomNavigationBar: t == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionPill(
                        icon: LucideIcons.reply,
                        label: 'Reply',
                        onTap: () => _compose(ComposeKind.reply, t.messages.last),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionPill(
                        icon: LucideIcons.forward,
                        label: 'Forward',
                        onTap: () => _compose(ComposeKind.forward, t.messages.last),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ActionPill(icon: LucideIcons.replyAll, onTap: () => _compose(ComposeKind.replyAll, t.messages.last)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _body(MailThread t) {
    final last = t.messages.last;
    final heroId = widget.heroMessageId ?? last.id;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Hero(
                      tag: 'subject-${t.id}-$heroId',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          t.subject.isEmpty ? last.subject : t.subject,
                          style: AppText.pageHeading2.copyWith(color: AppColors.ink),
                        ),
                      ),
                    ),
                    for (final l in last.labels.where((l) => l != 'sent'))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accentMuted, borderRadius: BorderRadius.circular(4)),
                        child: Text(systemLabels[l] ?? 'Label', style: AppText.chipLabel.copyWith(color: AppColors.ink)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final (i, m) in t.messages.indexed)
          EntryMotion(
            index: i,
            child: _MessageCard(
              message: m,
              heroAvatar: m.id == heroId,
              expanded: m.id == last.id || _expanded.contains(m.id),
              onToggle: () => setState(() => _expanded.contains(m.id) ? _expanded.remove(m.id) : _expanded.add(m.id)),
              onReply: () => _compose(ComposeKind.reply, m),
            ),
          ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.expanded,
    required this.onToggle,
    required this.onReply,
    required this.heroAvatar,
  });
  final Message message;
  final bool expanded;
  final bool heroAvatar;
  final VoidCallback onToggle;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final sender = m.outgoing ? 'Me' : m.from.display;
    final avatar = Avatar(name: m.from.display);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaperPress(
              onTap: onToggle,
              washRadius: 16,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heroAvatar ? Hero(tag: 'avatar-${m.id}', child: avatar) : avatar,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sender,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.rowTitle.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(shortDate(m.sentAt), style: AppText.docMeta.copyWith(color: AppColors.inkSoft)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expanded ? 'to ${m.to.map((a) => a.display).join(', ')}' : m.snippet,
                            maxLines: expanded ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyTight.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    if (expanded) IconPress(icon: LucideIcons.reply, label: 'Reply', size: 20, onTap: onReply),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: m.html != null && m.html!.trim().isNotEmpty
                    ? HtmlView(html: m.html!)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: SelectableText(m.text ?? '', style: AppText.pageBody.copyWith(color: AppColors.ink)),
                      ),
              ),
              if (m.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [for (final a in m.attachments) AttachmentChip(attachment: a)]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(longDate(m.sentAt), style: AppText.docMeta.copyWith(color: AppColors.inkFaint)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, this.label, required this.onTap});
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PaperPress(
    onTap: onTap,
    semanticLabel: label ?? 'Reply all',
    washRadius: 26,
    child: Container(
      height: 52,
      width: label == null ? 52 : null,
      decoration: BoxDecoration(color: AppColors.accentMuted, borderRadius: BorderRadius.circular(26)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.ink),
          if (label != null) ...[const SizedBox(width: 8), Text(label!, style: AppText.actionPill.copyWith(color: AppColors.ink))],
        ],
      ),
    ),
  );
}
