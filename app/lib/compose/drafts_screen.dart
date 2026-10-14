import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/accounts_controller.dart';
import '../core/db/database.dart';
import '../core/motion.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import '../mail/format.dart';
import 'compose_args.dart';
import 'compose_draft.dart';

final draftsProvider = FutureProvider.autoDispose<List<Draft>>(
  (ref) => ref.watch(databaseProvider).draftsFor(ref.watch(activeAccountProvider)!.id),
);

class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
        title: const Text('Drafts'),
      ),
      body: switch (drafts) {
        AsyncValue(value: final list?) when list.isEmpty => const EmptyState(
          icon: LucideIcons.file,
          title: 'No drafts',
          body: 'Anything you start writing is kept here until you send it.',
        ),
        AsyncValue(value: final list?) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final d = ComposeDraft.fromJson(jsonDecode(list[i].json));
            return EntryMotion(
              index: i,
              child: PaperPress(
                onTap: () async {
                  await context.push('/compose', extra: ComposeArgs(draftId: d.id));
                  ref.invalidate(draftsProvider);
                },
                child: ListTile(
                  leading: Icon(LucideIcons.filePen, color: AppColors.accentBright),
                  title: Text(d.subject.isEmpty ? '(no subject)' : d.subject, style: AppText.rowTitle.copyWith(color: AppColors.ink)),
                  subtitle: Text(
                    '${d.to.isEmpty ? 'No recipients' : d.to.join(', ')}  ·  ${shortDate(DateTime.fromMillisecondsSinceEpoch(list[i].updatedAt))}',
                    style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                  ),
                  trailing: IconPress(
                    icon: LucideIcons.trash2,
                    label: 'Discard',
                    size: 18,
                    color: AppColors.damage,
                    onTap: () async {
                      await ref.read(databaseProvider).deleteDraft(d.id);
                      ref.invalidate(draftsProvider);
                    },
                  ),
                ),
              ),
            );
          },
        ),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(draftsProvider)),
        _ => const Loader(),
      },
    );
  }
}
