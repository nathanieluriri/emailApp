import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'format.dart';
import 'models.dart';

class MailRow extends StatelessWidget {
  const MailRow({super.key, required this.message, required this.onTap, required this.onStar, this.onArchive, this.showRecipient = false});
  final Message message;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final VoidCallback? onArchive;
  final bool showRecipient;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final unread = !m.read;
    final name = showRecipient || m.outgoing ? 'To: ${m.to.map((a) => a.display).join(', ')}' : m.from.display;
    final strong = unread ? FontWeight.w700 : FontWeight.w400;
    final row = PaperPress(
      onTap: onTap,
      semanticLabel: '${m.from.display}, ${m.subject}',
      washRadius: 14,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'avatar-${m.id}',
              child: Avatar(name: m.outgoing && m.to.isNotEmpty ? m.to.first.display : m.from.display),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.rowTitle.copyWith(color: AppColors.ink, fontWeight: strong),
                        ),
                      ),
                      if (m.threadCount > 1) Text('  ${m.threadCount}', style: AppText.docMeta.copyWith(color: AppColors.inkSoft)),
                      const Spacer(),
                      Text(
                        shortDate(m.sentAt),
                        style: AppText.docMeta.copyWith(color: unread ? AppColors.ink : AppColors.inkSoft, fontWeight: strong),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: AppColors.accentBright, shape: BoxShape.circle),
                        ),
                      ],
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'subject-${m.threadId}-${m.id}',
                              child: Material(
                                type: MaterialType.transparency,
                                child: Text(
                                  m.subject.isEmpty ? '(no subject)' : m.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodyTight.copyWith(color: AppColors.ink, fontWeight: strong),
                                ),
                              ),
                            ),
                            Text(
                              m.snippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyTight.copyWith(color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      if (m.hasAttachments) Icon(LucideIcons.paperclip, size: 16, color: AppColors.inkSoft),
                      _Star(starred: m.starred, onTap: onStar),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onArchive == null) return row;
    return SwipeActions(id: m.id, onArchive: onArchive!, onStar: onStar, starred: m.starred, child: row);
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.starred, required this.onTap});
  final bool starred;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PaperPress(
    onTap: onTap,
    feel: Feel.turn,
    semanticLabel: starred ? 'Unstar' : 'Star',
    washRadius: 20,
    child: SizedBox.square(
      dimension: 40,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
        child: Icon(
          LucideIcons.star,
          key: ValueKey(starred),
          size: 20,
          color: starred ? AppColors.found : AppColors.inkSoft,
          fill: starred ? 1 : 0,
        ),
      ),
    ),
  );
}

/// Swipe left to archive, right to star. The action glyph grows as the row is dragged
/// and the phone ticks once when the swipe passes the point where it will act.
class SwipeActions extends StatefulWidget {
  const SwipeActions({
    super.key,
    required this.id,
    required this.child,
    required this.onArchive,
    required this.onStar,
    required this.starred,
  });
  final String id;
  final Widget child;
  final VoidCallback onArchive;
  final VoidCallback onStar;
  final bool starred;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions> {
  static const _threshold = 0.32;
  final _progress = ValueNotifier(0.0);
  DismissDirection? _direction;
  bool _armed = false;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Widget _reveal({required bool left}) => ValueListenableBuilder<double>(
    valueListenable: _progress,
    builder: (context, p, _) {
      final t = (p / _threshold).clamp(0.0, 1.0);
      final archive = left;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.surfaceHigh, archive ? AppColors.accent : AppColors.found, t),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: archive ? Alignment.centerRight : Alignment.centerLeft,
        child: Transform.scale(
          scale: 0.6 + 0.5 * Curves.easeOutBack.transform(t),
          child: Icon(
            archive ? LucideIcons.archive : LucideIcons.star,
            color: archive ? AppColors.onAccent : Colors.black87,
            fill: !archive && !widget.starred ? 1 : 0,
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('swipe-${widget.id}'),
    background: _reveal(left: false),
    secondaryBackground: _reveal(left: true),
    dismissThresholds: const {DismissDirection.startToEnd: _threshold, DismissDirection.endToStart: _threshold},
    onUpdate: (d) {
      _direction = d.direction;
      _progress.value = d.progress;
      final armed = d.progress >= _threshold;
      if (armed != _armed) {
        _armed = armed;
        if (armed) Feel.turn.ring();
      }
    },
    confirmDismiss: (direction) async {
      if (direction == DismissDirection.startToEnd) {
        Feel.commit.ring();
        widget.onStar();
        return false;
      }
      return true;
    },
    onDismissed: (_) {
      Feel.commit.ring();
      if (_direction == DismissDirection.endToStart) widget.onArchive();
    },
    child: widget.child,
  );
}
