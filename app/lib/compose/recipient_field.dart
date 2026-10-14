import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Addresses become chips on space, comma or enter; a bad address turns red instead of vanishing.
class RecipientField extends StatefulWidget {
  const RecipientField({super.key, required this.label, required this.values, required this.onChanged, this.trailing});
  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final Widget? trailing;

  @override
  State<RecipientField> createState() => RecipientFieldState();
}

class RecipientFieldState extends State<RecipientField> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) commit();
    });
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
    Feel.tap.ring();
    _input.clear();
    widget.onChanged([...widget.values, ...parts.where((p) => !widget.values.contains(p))]);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(widget.label, style: AppText.search.copyWith(color: AppColors.inkSoft)),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final v in widget.values)
                TweenAnimationBuilder<double>(
                  key: ValueKey(v),
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: _Chip(
                    text: v,
                    valid: _email.hasMatch(v),
                    onRemove: () => widget.onChanged(widget.values.where((x) => x != v).toList()),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120),
                child: IntrinsicWidth(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    keyboardType: TextInputType.emailAddress,
                    style: AppText.search.copyWith(color: AppColors.ink),
                    decoration: bareInput(),
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
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.valid, required this.onRemove});
  final String text;
  final bool valid;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
    decoration: BoxDecoration(
      border: Border.all(color: valid ? AppColors.hairline : AppColors.damage),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(name: text, size: 24),
        const SizedBox(width: 6),
        Text(text, style: AppText.label.copyWith(color: valid ? AppColors.ink : AppColors.damage)),
        PaperPress(
          onTap: onRemove,
          semanticLabel: 'Remove $text',
          washRadius: 12,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(LucideIcons.x, size: 14, color: AppColors.inkSoft),
          ),
        ),
      ],
    ),
  );
}

bool isValidEmail(String s) => _email.hasMatch(s);
