import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../compose/compose_args.dart';
import '../core/motion.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'starters.dart';
import 'template.dart';
import 'templates_repository.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key, this.pick = false});
  final bool pick;

  Future<void> _open(BuildContext context, WidgetRef ref, MailTemplate t) async {
    if (pick) return context.pop(t);
    final starter = t.id.startsWith('starter-');
    await showQuireSheet(
      context,
      (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetTitle(t.name),
          SheetRow(
            label: 'Use in a new email',
            icon: LucideIcons.pencil,
            onTap: () {
              Navigator.pop(sheet);
              context.push('/compose', extra: ComposeArgs(template: t));
            },
          ),
          SheetRow(
            label: starter ? 'Customise a copy' : 'Edit',
            icon: LucideIcons.layoutTemplate,
            onTap: () {
              Navigator.pop(sheet);
              context.push('/templates/edit', extra: t);
            },
          ),
          if (!starter) ...[
            SheetRow(
              label: 'Duplicate',
              icon: LucideIcons.copy,
              onTap: () async {
                Navigator.pop(sheet);
                await ref.read(templatesProvider.notifier).duplicate(t).catchError((Object e) {
                  if (context.mounted) showToast(context, '$e');
                });
              },
            ),
            SheetRow(
              label: 'Delete',
              icon: LucideIcons.trash2,
              destructive: true,
              onTap: () async {
                Navigator.pop(sheet);
                if (await confirm(context, title: 'Delete "${t.name}"?', action: 'Delete template')) {
                  await ref.read(templatesProvider.notifier).delete(t.id).catchError((Object e) {
                    if (context.mounted) showToast(context, '$e');
                  });
                }
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(templatesProvider);
    Widget grid(List<MailTemplate> list) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: list.length,
        itemBuilder: (context, i) => EntryMotion(
          index: i,
          child: _TemplateCard(template: list[i], onTap: () => _open(context, ref, list[i])),
        ),
      ),
    );
    Widget heading(String text) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Text(text, style: AppText.sortLabel.copyWith(color: AppColors.inkSoft)),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back', onTap: () => context.pop()),
        title: Text(pick ? 'Pick a template' : 'Templates'),
        actions: [
          if (!pick)
            IconPress(
              icon: LucideIcons.plus,
              label: 'New template',
              onTap: () => context.push(
                '/templates/edit',
                extra: const MailTemplate(id: '', name: 'Untitled template'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(templatesProvider.future),
        child: CustomScrollView(
          slivers: [
            heading('Your templates'),
            switch (saved) {
              AsyncValue(value: final list?) when list.isEmpty => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Save any email as a template, or start from one below.',
                    style: AppText.bodyTight.copyWith(color: AppColors.inkFaint),
                  ),
                ),
              ),
              AsyncValue(value: final list?) => grid(list),
              AsyncError(:final error) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
                  child: ErrorView(error: error, onRetry: () => ref.invalidate(templatesProvider)),
                ),
              ),
              _ => const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.all(24), child: Loader()),
              ),
            },
            heading('Starters'),
            grid(starterTemplates),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});
  final MailTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PaperPress(
    onTap: onTap,
    semanticLabel: template.name,
    washRadius: 16,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 8, width: 70, color: const Color(0xFF4F378B)),
                  const SizedBox(height: 8),
                  for (final w in [1.0, 0.9, 0.75]) ...[
                    FractionallySizedBox(
                      widthFactor: w,
                      child: Container(height: 5, color: const Color(0xFFE2DDE6)),
                    ),
                    const SizedBox(height: 5),
                  ],
                  const Spacer(),
                  Container(
                    height: 14,
                    width: 52,
                    decoration: BoxDecoration(color: const Color(0xFF4F378B), borderRadius: BorderRadius.circular(7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            template.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.rowTitle.copyWith(color: AppColors.ink),
          ),
          Text(
            template.variables.isEmpty ? (template.subject ?? '') : template.variables.map((v) => '{{$v}}').join(' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    ),
  );
}
