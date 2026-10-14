import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/motion.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import '../compose/html_tools.dart';
import 'signature.dart';
import 'signatures_repository.dart';

class SignaturesScreen extends ConsumerWidget {
  const SignaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signatures = ref.watch(signaturesProvider);
    final auto = ref.watch(settingsProvider).autoSignature;
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
        title: const Text('Signatures'),
      ),
      floatingActionButton: PillButton(
        label: 'New signature',
        icon: LucideIcons.plus,
        onTap: () => context.push(
          '/signatures/edit',
          extra: const Signature(id: '', name: 'My signature', isDefault: true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          SwitchListTile(
            value: auto,
            title: Text('Add signature automatically', style: AppText.rowTitle.copyWith(color: AppColors.ink)),
            subtitle: Text('On every new email and reply, above quoted text', style: AppText.docMeta.copyWith(color: AppColors.inkSoft)),
            onChanged: (v) {
              Feel.tap.ring();
              ref.read(settingsProvider.notifier).setAutoSignature(v);
            },
          ),
          Divider(color: AppColors.hairline),
          ...switch (signatures) {
            AsyncValue(value: final list?) when list.isEmpty => [
              const SizedBox(
                height: 360,
                child: EmptyState(
                  icon: LucideIcons.signature,
                  title: 'No signatures yet',
                  body: 'Make one with the quick generator or the builder.',
                ),
              ),
            ],
            AsyncValue(value: final list?) => [
              for (final (i, s) in list.indexed)
                EntryMotion(
                  index: i,
                  child: PaperPress(
                    onTap: () => context.push('/signatures/edit', extra: s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Icon(LucideIcons.signature, color: AppColors.accentBright),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: AppText.rowTitle.copyWith(color: AppColors.ink)),
                                Text(
                                  '${s.senderAddress ?? 'All senders'}${s.isDefault ? '  ·  Default' : ''}',
                                  style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                                ),
                                Text(
                                  htmlToPlain(s.html),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.docMeta.copyWith(color: AppColors.inkFaint),
                                ),
                              ],
                            ),
                          ),
                          IconPress(
                            icon: LucideIcons.trash2,
                            label: 'Delete',
                            size: 18,
                            color: AppColors.damage,
                            onTap: () async {
                              if (await confirm(context, title: 'Delete "${s.name}"?', action: 'Delete signature')) {
                                await ref.read(signaturesProvider.notifier).delete(s.id).catchError((Object e) {
                                  if (context.mounted) showToast(context, '$e');
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            AsyncError(:final error) => [
              SizedBox(
                height: 360,
                child: ErrorView(error: error, onRetry: () => ref.invalidate(signaturesProvider)),
              ),
            ],
            _ => [const Padding(padding: EdgeInsets.all(32), child: Loader())],
          },
        ],
      ),
    );
  }
}
