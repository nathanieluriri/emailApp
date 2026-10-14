import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/accounts_controller.dart';
import '../compose/compose_args.dart';
import '../core/confetti.dart';
import '../core/goo_menu.dart';
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
import 'quote.dart';
import 'reaction_widgets.dart';
import 'reactions.dart';

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId, this.heroMessageId});
  final String threadId;
  final String? heroMessageId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _expanded = <String>{};
  final _markedRead = <String>{};

  @override
  void initState() {
    super.initState();
    precacheReactionEmoji();
  }

  void _markRead(MailThread t) {
    final unread = t.messages.where((m) => !m.read && !_markedRead.contains(m.id)).map((m) => m.id).toList();
    if (unread.isEmpty) return;
    _markedRead.addAll(unread);
    ref.read(mailRepositoryProvider).api.updateThread(t.id, read: true).then((_) {
      if (mounted) ref.invalidate(labelsProvider);
    }).ignore();
    ref.read(inboxProvider(ref.read(currentLabelProvider)).notifier).markThreadRead(t.id);
  }

  Future<void> _act(String done, Future<void> Function() action, {bool leave = true, Future<void> Function()? undo}) async {
    Feel.commit.ring();
    final container = ProviderScope.containerOf(context);
    try {
      await action();
      ref.invalidate(inboxProvider);
      ref.invalidate(labelsProvider);
      if (!mounted) return;
      showToast(
        context,
        done,
        action: undo == null ? null : 'Undo',
        onAction: undo == null
            ? null
            : () => undo().then((_) {
                container
                  ..invalidate(inboxProvider)
                  ..invalidate(labelsProvider);
              }).ignore(),
      );
      if (leave) context.pop();
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  Future<void> _react(BuildContext anchor, Message m) async {
    final blocked = reactionBlocker(m, ref.read(activeAccountProvider)?.email.toLowerCase() ?? '');
    if (blocked != null) return showToast(context, blocked);
    final box = anchor.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(box.size.center(Offset.zero));
    final emoji = await showReactionBar(anchor);
    if (emoji == null || !mounted) return;
    final pending = ref.read(pendingReactionsProvider.notifier);
    final already = [...m.reactions, ...?ref.read(pendingReactionsProvider)[m.id]].any((r) => r.mine && r.emoji == emoji);
    if (already) return showToast(context, 'You already reacted with $emoji');
    final sent = pending.add(m, emoji);
    if (emoji == '🎉') showConfetti(context, origin);
    showToast(context, 'Sent $emoji', action: 'Undo', onAction: () => pending.undo(m.id, emoji));
    sent.catchError((Object e) {
      if (mounted) showToast(context, 'Reaction not sent: $e');
      return false;
    }).ignore();
  }

  void _compose(ComposeKind kind, Message m) => context.push(
    '/compose',
    extra: ComposeArgs(kind: kind, source: m),
  );

  Future<void> _menu(BuildContext anchor, MailThread t) async {
    final api = ref.read(mailRepositoryProvider).api;
    final last = t.messages.last;
    final starred = t.messages.any((m) => m.starred);
    final spam = t.messages.any((m) => m.labels.contains('spam'));
    final picked = await showGooMenu(anchor, [
      const GooMenuItem(label: 'Label as', icon: LucideIcons.tag),
      GooMenuItem(label: starred ? 'Remove star' : 'Add star', icon: LucideIcons.star),
      const GooMenuItem(label: 'Mark unread', icon: LucideIcons.mailOpen),
      const GooMenuItem(label: 'Forward', icon: LucideIcons.forward),
      GooMenuItem(
        label: spam ? 'Not spam' : 'Report spam',
        icon: spam ? LucideIcons.shieldCheck : LucideIcons.octagonAlert,
        destructive: !spam,
      ),
    ]);
    if (!mounted) return;
    switch (picked) {
      case 0:
        final current = {for (final m in t.messages) ...m.labels}..remove('sent');
        final labels = await pickLabels(context, [...current]);
        if (labels == null) return;
        final add = labels.where((l) => !current.contains(l)).toList();
        final remove = current.where((l) => !labels.contains(l)).toList();
        final archived = add.remove('inbox') ? false : (remove.remove('inbox') ? true : null);
        await _act('Labels updated', () => api.updateThread(t.id, add: add, remove: remove, archived: archived), leave: false);
        ref.invalidate(threadProvider(widget.threadId));
      case 1:
        await _act(starred ? 'Star removed' : 'Starred', () => api.updateThread(t.id, starred: !starred), leave: false);
        ref.invalidate(threadProvider(widget.threadId));
      case 2:
        await _act('Marked unread', () => api.updateMessage(_lastReceived(t).id, read: false));
      case 3:
        _compose(ComposeKind.forward, last);
      case 4:
        await _act(
          spam ? 'Moved to Inbox' : 'Moved to Spam',
          () => spam ? api.updateThread(t.id, remove: ['spam'], archived: false) : api.updateThread(t.id, add: ['spam'], remove: ['inbox']),
        );
    }
  }

  Message _lastReceived(MailThread t) => t.messages.lastWhere((m) => !m.outgoing, orElse: () => t.messages.last);

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
                  onTap: () =>
                      _act('Archived', () => api.updateThread(t.id, archived: true), undo: () => api.updateThread(t.id, archived: false)),
                ),
                IconPress(
                  icon: LucideIcons.trash2,
                  label: 'Delete',
                  onTap: () => _act(
                    'Moved to Trash',
                    () => api.updateThread(t.id, add: ['trash'], remove: ['inbox']),
                    undo: () => api.updateThread(t.id, remove: ['trash'], archived: false),
                  ),
                ),
                IconPress(
                  icon: LucideIcons.mail,
                  label: 'Mark unread',
                  onTap: () => _act('Marked unread', () => api.updateMessage(_lastReceived(t).id, read: false)),
                ),
                Builder(
                  builder: (anchor) => IconPress(icon: LucideIcons.ellipsisVertical, label: 'More', onTap: () => _menu(anchor, t)),
                ),
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
                    _ActionPill(icon: LucideIcons.reply, onTap: () => _compose(ComposeKind.reply, t.messages.last)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionPill(
                        icon: LucideIcons.replyAll,
                        label: 'Reply all',
                        onTap: () => _compose(ComposeKind.replyAll, t.messages.last),
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
                    Builder(
                      builder: (anchor) => _ActionPill(
                        icon: LucideIcons.smilePlus,
                        semanticLabel: 'Add reaction',
                        onTap: () => _react(anchor, t.messages.last),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _body(MailThread t) {
    final last = t.messages.last;
    final heroId = widget.heroMessageId ?? last.id;
    final labels = {for (final l in ref.watch(labelsProvider).value ?? <MailLabel>[]) l.id: l.name};
    final api = ref.read(mailRepositoryProvider).api;
    final pending = ref.watch(pendingReactionsProvider);
    final starred = t.messages.any((m) => m.starred);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 14),
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
                          style: AppText.pageHeading1.copyWith(color: AppColors.ink, fontWeight: FontWeight.w400),
                        ),
                      ),
                    ),
                    for (final l in last.labels.where((l) => l != 'sent'))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accentMuted, borderRadius: BorderRadius.circular(4)),
                        child: Text(labels[l] ?? systemLabels[l] ?? l, style: AppText.label.copyWith(color: AppColors.ink)),
                      ),
                  ],
                ),
              ),
              IconPress(
                icon: LucideIcons.star,
                label: starred ? 'Remove star' : 'Add star',
                color: starred ? AppColors.found : AppColors.inkSoft,
                onTap: () async {
                  Feel.turn.ring();
                  await api.updateThread(t.id, starred: !starred);
                  ref.invalidate(threadProvider(widget.threadId));
                  ref.invalidate(inboxProvider);
                },
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
              expanded: m.id == last.id || !m.read || _expanded.contains(m.id),
              reactions: groupedReactions(m, pending[m.id] ?? const []),
              fresh: {
                for (final r in pending[m.id] ?? const <Reaction>[])
                  if (!m.reactions.any((x) => x.mine && x.emoji == r.emoji)) r.emoji,
              },
              onToggle: () => setState(() => _expanded.contains(m.id) ? _expanded.remove(m.id) : _expanded.add(m.id)),
              onReply: () => _compose(ComposeKind.reply, m),
              onReact: (anchor) => _react(anchor, m),
              onMore: (anchor) async {
                final picked = await showGooMenu(anchor, const [
                  GooMenuItem(label: 'Reply all', icon: LucideIcons.replyAll),
                  GooMenuItem(label: 'Forward', icon: LucideIcons.forward),
                  GooMenuItem(label: 'Mark unread from here', icon: LucideIcons.mailOpen),
                ]);
                switch (picked) {
                  case 0:
                    _compose(ComposeKind.replyAll, m);
                  case 1:
                    _compose(ComposeKind.forward, m);
                  case 2:
                    await _act('Marked unread', () => api.updateMessage(m.id, read: false));
                }
              },
            ),
          ),
      ],
    );
  }
}

class _MessageCard extends StatefulWidget {
  const _MessageCard({
    required this.message,
    required this.expanded,
    required this.reactions,
    required this.fresh,
    required this.onToggle,
    required this.onReply,
    required this.onReact,
    required this.onMore,
    required this.heroAvatar,
  });
  final Message message;
  final bool expanded;
  final List<(String, List<Reaction>)> reactions;
  final Set<String> fresh;
  final bool heroAvatar;
  final VoidCallback onToggle;
  final VoidCallback onReply;
  final ValueChanged<BuildContext> onReact;
  final ValueChanged<BuildContext> onMore;

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  bool _details = false;
  bool _quoted = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final expanded = widget.expanded;
    final sender = m.outgoing ? 'Me' : m.from.display;
    final avatar = Avatar(name: m.from.display, size: 44);
    final recipients = m.to.map((a) => a.display).join(', ');
    final hasHtml = m.html != null && m.html!.trim().isNotEmpty;
    final (body, quoted) = hasHtml ? splitQuotedHtml(m.html!) : splitQuotedText(m.text ?? '');
    final meta = AppText.bodyTight.copyWith(color: AppColors.inkSoft, fontSize: 14);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaperPress(
              onTap: widget.onToggle,
              washRadius: 18,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.heroAvatar ? Hero(tag: 'avatar-${m.id}', child: avatar) : avatar,
                    const SizedBox(width: 14),
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
                                  style: AppText.rowTitle.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 17),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(shortDate(m.sentAt), style: meta),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (expanded)
                            GestureDetector(
                              onTap: () {
                                Feel.tap.ring();
                                setState(() => _details = !_details);
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'to ${m.outgoing ? recipients : 'me'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: meta,
                                    ),
                                  ),
                                  Icon(_details ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16, color: AppColors.inkSoft),
                                ],
                              ),
                            )
                          else
                            Text(m.snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
                        ],
                      ),
                    ),
                    if (expanded) ...[
                      Builder(
                        builder: (anchor) =>
                            IconPress(icon: LucideIcons.smilePlus, label: 'Add reaction', size: 22, onTap: () => widget.onReact(anchor)),
                      ),
                      IconPress(icon: LucideIcons.reply, label: 'Reply', size: 22, onTap: widget.onReply),
                      Builder(
                        builder: (anchor) =>
                            IconPress(icon: LucideIcons.ellipsisVertical, label: 'More', size: 22, onTap: () => widget.onMore(anchor)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: !_details
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Detail('From', '${m.from.display}  ${m.from.address}'),
                            _Detail('To', m.to.map((a) => a.address).join(', ')),
                            if (m.cc.isNotEmpty) _Detail('Cc', m.cc.map((a) => a.address).join(', ')),
                            _Detail('Date', longDate(m.sentAt)),
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: hasHtml
                    ? HtmlView(html: _quoted && quoted != null ? m.html! : body, dark: AppColors.current.brightness == Brightness.dark)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: SelectableText(
                          _quoted && quoted != null ? m.text ?? '' : body,
                          style: AppText.pageBody.copyWith(color: AppColors.ink, fontSize: 17, height: 1.5),
                        ),
                      ),
              ),
              if (quoted != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      Feel.tap.ring();
                      setState(() => _quoted = !_quoted);
                    },
                    child: Text(
                      _quoted ? 'Hide quoted text' : 'Show quoted text',
                      style: AppText.search.copyWith(color: AppColors.accentBright),
                    ),
                  ),
                ),
              if (m.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [for (final a in m.attachments) AttachmentChip(attachment: a)]),
                ),
              if (widget.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: ReactionChips(
                    groups: widget.reactions,
                    fresh: widget.fresh,
                    onAdd: widget.onReact,
                    onOpen: () => showReactors(context, widget.reactions),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: AppText.bodyTight.copyWith(color: AppColors.inkSoft)),
        ),
        Expanded(
          child: SelectableText(value, style: AppText.bodyTight.copyWith(color: AppColors.ink)),
        ),
      ],
    ),
  );
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, this.label, this.semanticLabel, required this.onTap});
  final IconData icon;
  final String? label;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PaperPress(
    onTap: onTap,
    semanticLabel: label ?? semanticLabel ?? 'Reply',
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
