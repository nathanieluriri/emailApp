import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/easings.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/digit_roll.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'models.dart';
import 'reactions.dart';

const _animated = {'💖': '1f496', '👍': '1f44d', '🎉': '1f389', '😂': '1f602', '🙏': '1f64f', '😊': '1f60a'};

String _asset(String code) => 'assets/emoji/$code.json';

/// Loads the quick reactions' animations ahead, so the bar never opens on blanks.
void precacheReactionEmoji() {
  for (final code in _animated.values) {
    AssetLottie(_asset(code)).load().ignore();
  }
}

enum EmojiMotion { still, once, loop }

/// Noto's animated emoji for the quick reactions, the phone's emoji for the rest.
class EmojiGlyph extends StatefulWidget {
  const EmojiGlyph(this.emoji, {super.key, this.size = 28, this.motion = EmojiMotion.still});
  final String emoji;
  final double size;
  final EmojiMotion motion;

  @override
  State<EmojiGlyph> createState() => _EmojiGlyphState();
}

class _EmojiGlyphState extends State<EmojiGlyph> with SingleTickerProviderStateMixin {
  // 🎉 and 😊 start and end on a bare cone and a plain smile; they read as themselves mid-animation.
  static const _rest = {'🎉': 0.45, '😊': 0.4};
  late final double _still = _rest[widget.emoji] ?? 0;
  late final _clock = AnimationController(vsync: this, value: _still);

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _loaded(LottieComposition composition) {
    _clock.duration = composition.duration;
    switch (widget.motion) {
      case EmojiMotion.loop:
        _clock.repeat();
      case EmojiMotion.once when _still > 0:
        _clock
          ..value = 0
          ..animateTo(_still, duration: composition.duration * _still);
      case EmojiMotion.once:
        _clock.forward(from: 0);
      case EmojiMotion.still:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox.square(
      dimension: widget.size,
      child: Center(
        child: Text(widget.emoji, style: TextStyle(fontSize: widget.size * 0.8, height: 1)),
      ),
    );
    final code = _animated[widget.emoji];
    return ExcludeSemantics(
      child: code == null
          ? glyph
          : Lottie.asset(
              _asset(code),
              width: widget.size,
              height: widget.size,
              controller: _clock,
              onLoaded: _loaded,
              errorBuilder: (_, _, _) => glyph,
            ),
    );
  }
}

/// Gmail's reaction bar: the quick reactions pop out of the button that was pressed.
/// Completes with the picked emoji, or null when dismissed.
Future<String?> showReactionBar(BuildContext anchor) {
  final box = anchor.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  return Navigator.of(anchor).push<String>(
    PageRouteBuilder<String>(
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => _ReactionBar(anchor: rect),
    ),
  );
}

class _ReactionBar extends StatefulWidget {
  const _ReactionBar({required this.anchor});
  final Rect anchor;

  @override
  State<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<_ReactionBar> with SingleTickerProviderStateMixin {
  static const _height = 58.0;
  late final _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..forward();
  bool _closing = false;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  Future<void> _close([String? picked]) async {
    if (_closing) return;
    _closing = true;
    if (picked == null) Feel.tap.ring();
    await _open.animateBack(0, duration: const Duration(milliseconds: 170), curve: easeInCubic);
    if (mounted) Navigator.of(context).pop(picked);
  }

  Future<void> _more() async {
    final picked = await showEmojiPicker(context);
    if (picked != null) _close(picked);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final cell = ((size.width - 36) / (quickReactions.length + 1)).clamp(34.0, 46.0);
    final width = cell * (quickReactions.length + 1) + 12;
    final left = (widget.anchor.right + 6 - width).clamp(12.0, max(12.0, size.width - width - 12)).toDouble();
    final above = widget.anchor.top - _height - 6 > padding.top + 8;
    final top = above ? widget.anchor.top - _height - 6 : widget.anchor.bottom + 6;
    final origin = Alignment(((widget.anchor.center.dx - left) / width) * 2 - 1, above ? 1 : -1);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _close()),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            height: _height,
            child: AnimatedBuilder(
              animation: _open,
              builder: (context, child) {
                final t = _open.value;
                return Opacity(
                  opacity: Curves.easeOut.transform((t * 3).clamp(0.0, 1.0)),
                  child: Transform.scale(
                    scale: 0.4 + 0.6 * Curves.easeOutBack.transform((t * 1.6).clamp(0.0, 1.0)),
                    alignment: origin,
                    child: child,
                  ),
                );
              },
              child: Material(
                color: AppColors.surfaceHigh,
                elevation: 6,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(_height / 2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      for (final (i, emoji) in quickReactions.indexed)
                        _Pop(
                          open: _open,
                          index: i,
                          child: PaperPress(
                            onTap: () => _close(emoji),
                            feel: Feel.commit,
                            semanticLabel: 'React with $emoji',
                            washRadius: cell / 2,
                            child: SizedBox.square(
                              dimension: cell,
                              child: Center(
                                child: EmojiGlyph(emoji, size: cell - 12, motion: EmojiMotion.loop),
                              ),
                            ),
                          ),
                        ),
                      _Pop(
                        open: _open,
                        index: quickReactions.length,
                        child: PaperPress(
                          onTap: _more,
                          semanticLabel: 'More reactions',
                          washRadius: cell / 2,
                          child: SizedBox.square(
                            dimension: cell,
                            child: Center(
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                                child: Icon(LucideIcons.plus, size: 18, color: AppColors.ink),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pop extends StatelessWidget {
  const _Pop({required this.open, required this.index, required this.child});
  final Animation<double> open;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = 0.12 + index * 0.06;
    final pop = CurvedAnimation(
      parent: open,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.elasticOut),
    );
    return ScaleTransition(scale: pop, child: child);
  }
}

const _groups = {
  'Smileys': '😀 😃 😄 😁 😆 😅 🤣 😂 🙂 😉 😊 😇 🥰 😍 🤩 😘 😋 😛 😜 🤪 🤗 🤭 🤔 🤨 😐 😏 😒 🙄 😬 😌 😔 😴 😷 🥳 😎 🤓 😕 😮 😲 😳 🥺 😢 😭 😱 😤 😡 🤯 🤡 👻 🤖',
  'Hands': '👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 👋 👏 🙌 👐 🤲 🙏 🤝 💪 ✍️ 👀',
  'Hearts': '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝',
  'Celebrate': '🎉 🎊 🎈 🎂 🎁 🏆 🥇 ⭐ 🌟 ✨ 🔥 💯 ✅ ❌ ⚡ 💡 🚀 🍾 🥂 ☕ 🌹 🌈 ☀️ 📌',
};

Future<String?> showEmojiPicker(BuildContext context) => showQuireSheet<String>(context, (context) => const _EmojiPicker());

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SheetTitle('Add reaction'),
      Flexible(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              for (final MapEntry(key: group, value: emoji) in _groups.entries) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: Text(group, style: AppText.label.copyWith(color: AppColors.inkSoft)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid.extent(
                    maxCrossAxisExtent: 52,
                    children: [
                      for (final e in emoji.split(' '))
                        PaperPress(
                          onTap: () => Navigator.of(context).pop(e),
                          feel: Feel.commit,
                          semanticLabel: 'React with $e',
                          washRadius: 24,
                          child: Center(child: EmojiGlyph(e, size: 32)),
                        ),
                    ],
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        ),
      ),
    ],
  );
}

/// The reactions under a message: one chip per emoji with its count, then a button to add one.
class ReactionChips extends StatelessWidget {
  const ReactionChips({super.key, required this.groups, required this.fresh, required this.onAdd, required this.onOpen});
  final List<(String, List<Reaction>)> groups;

  /// Emoji we just reacted with; they pop in and play once.
  final Set<String> fresh;
  final ValueChanged<BuildContext> onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final (emoji, list) in groups)
        _Chip(
          key: ValueKey(emoji),
          emoji: emoji,
          count: list.length,
          mine: list.any((r) => r.mine),
          fresh: fresh.contains(emoji),
          onTap: onOpen,
        ),
      Builder(
        builder: (anchor) => PaperPress(
          onTap: () => onAdd(anchor),
          semanticLabel: 'Add reaction',
          washRadius: 16,
          child: Container(
            width: 44,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(LucideIcons.smilePlus, size: 18, color: AppColors.inkSoft),
          ),
        ),
      ),
    ],
  );
}

class _Chip extends StatefulWidget {
  const _Chip({super.key, required this.emoji, required this.count, required this.mine, required this.fresh, required this.onTap});
  final String emoji;
  final int count;
  final bool mine;
  final bool fresh;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), value: widget.fresh ? 0 : 1)..forward();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    return ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
      child: PaperPress(
        onTap: widget.onTap,
        semanticLabel: '${widget.emoji} ${widget.count}',
        washRadius: 16,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 32,
          padding: const EdgeInsets.only(left: 8, right: 10),
          decoration: BoxDecoration(
            color: mine ? AppColors.accentMuted : AppColors.surfaceHigh,
            border: Border.all(color: mine ? AppColors.accentBright : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmojiGlyph(widget.emoji, size: 22, motion: widget.fresh ? EmojiMotion.once : EmojiMotion.still),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: DigitRoll('${widget.count}', style: AppText.label, color: mine ? AppColors.accentBright : AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who reacted with what, Gmail's sheet behind a reaction chip.
Future<void> showReactors(BuildContext context, List<(String, List<Reaction>)> groups) => showQuireSheet<void>(
  context,
  (context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SheetTitle('Reactions'),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            for (final (emoji, list) in groups)
              for (final r in list)
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        EmojiGlyph(emoji, size: 30),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            r.who,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.menuRow.copyWith(color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    ],
  ),
);
