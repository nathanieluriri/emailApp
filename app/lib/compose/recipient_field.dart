import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'contacts.dart';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String s) => _email.hasMatch(s);

/// Gmail's recipient row: chips with faces, a folded "+N" when you leave it, and suggestions as you type.
class RecipientField extends ConsumerStatefulWidget {
  const RecipientField({super.key, required this.label, required this.values, required this.onChanged, this.leading, this.trailing});
  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final Widget? leading;
  final Widget? trailing;

  @override
  ConsumerState<RecipientField> createState() => RecipientFieldState();
}

class RecipientFieldState extends ConsumerState<RecipientField> {
  static const _folded = 2;
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) commit();
      setState(() {});
    });
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void commit() {
    final parts = _input.text.split(RegExp(r'[\s,;]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;
    _input.clear();
    _add(parts);
  }

  void _add(List<String> addresses) {
    Feel.tap.ring();
    widget.onChanged([...widget.values, ...addresses.where((p) => !widget.values.contains(p))]);
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final names = {for (final c in contacts) c.address: c.display};
    final shown = focused || widget.values.length <= _folded + 1 ? widget.values : widget.values.take(_folded).toList();
    final hidden = widget.values.length - shown.length;
    final query = _input.text.trim().toLowerCase();
    final suggestions = query.isEmpty || !focused
        ? const <Contact>[]
        : contacts.where((c) => c.address.contains(query) || c.name.toLowerCase().contains(query)).take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focus.requestFocus,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: widget.leading ?? Text(widget.label, style: AppText.search.copyWith(color: AppColors.inkSoft, fontSize: 16)),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final v in shown)
                        TweenAnimationBuilder<double>(
                          key: ValueKey(v),
                          tween: Tween(begin: 0.6, end: 1),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          builder: (context, s, child) => Transform.scale(scale: s, child: child),
                          child: _Chip(
                            text: names[v.toLowerCase()] ?? v,
                            seed: v,
                            valid: isValidEmail(v),
                            removable: focused,
                            onRemove: () => widget.onChanged(widget.values.where((x) => x != v).toList()),
                          ),
                        ),
                      if (hidden > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.hairline),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text('+$hidden', style: AppText.label.copyWith(color: AppColors.ink)),
                        ),
                      if (focused || widget.values.isEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 140),
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: _input,
                              focusNode: _focus,
                              keyboardType: TextInputType.emailAddress,
                              style: AppText.search.copyWith(color: AppColors.ink, fontSize: 16),
                              decoration: bareInput(padding: const EdgeInsets.symmetric(vertical: 8)),
                              onChanged: (v) {
                                if (RegExp(r'[\s,;]$').hasMatch(v)) commit();
                              },
                              onSubmitted: (_) => commit(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ?widget.trailing,
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: suggestions.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                      child: Text('Suggestions', style: AppText.label.copyWith(color: AppColors.inkSoft)),
                    ),
                    for (final c in suggestions)
                      PaperPress(
                        onTap: () {
                          _input.clear();
                          if (!widget.values.contains(c.address)) _add([c.address]);
                        },
                        semanticLabel: 'Add ${c.address}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              Avatar(name: c.display),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.display,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.rowTitle.copyWith(color: AppColors.ink),
                                    ),
                                    Text(
                                      c.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.values.contains(c.address))
                                Text('Selected', style: AppText.label.copyWith(color: AppColors.inkSoft))
                              else if (c.you)
                                Text('You', style: AppText.label.copyWith(color: AppColors.inkSoft)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.seed, required this.valid, required this.removable, required this.onRemove});
  final String text;
  final String seed;
  final bool valid;
  final bool removable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(3, 3, 12, 3),
    decoration: BoxDecoration(
      border: Border.all(color: valid ? AppColors.inkFaint.withValues(alpha: 0.6) : AppColors.damage),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(name: text, size: 28),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.search.copyWith(color: valid ? AppColors.ink : AppColors.damage, fontSize: 15),
          ),
        ),
        if (removable)
          PaperPress(
            onTap: onRemove,
            semanticLabel: 'Remove $text',
            washRadius: 12,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(LucideIcons.x, size: 15, color: AppColors.inkSoft),
            ),
          ),
      ],
    ),
  );
}
