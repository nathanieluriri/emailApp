import 'package:flutter/material.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/typography.dart';
import '../core/widgets.dart';

/// Asks for every `{{variable}}` before sending. Pops with the values, or null when cancelled.
Future<Map<String, String>?> askVariables(BuildContext context, List<String> names) =>
    showQuireSheet<Map<String, String>>(context, (context) {
      final values = {for (final n in names) n: TextEditingController()};
      String pretty(String n) => n.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('Fill in the blanks'),
            Text('These appear in your email as {{name}}.', style: AppText.bodyTight.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            for (final (i, n) in names.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: values[n],
                  autofocus: i == 0,
                  textInputAction: i == names.length - 1 ? TextInputAction.done : TextInputAction.next,
                  decoration: InputDecoration(labelText: pretty(n)),
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: PillButton(
                label: 'Use these',
                onTap: () => Navigator.pop(context, {for (final e in values.entries) e.key: e.value.text.trim()}),
              ),
            ),
          ],
        ),
      );
    });
