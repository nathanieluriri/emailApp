import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../builder/upload.dart';
import '../compose/body_editor.dart';
import '../compose/preview.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/quire_spinner.dart';
import '../core/widgets.dart';
import 'template.dart';
import 'templates_repository.dart';
import 'variables.dart';

class TemplateEditor extends ConsumerStatefulWidget {
  const TemplateEditor({super.key, required this.template});
  final MailTemplate template;

  @override
  ConsumerState<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<TemplateEditor> {
  late final _name = TextEditingController(
    text: widget.template.id.startsWith('starter-') ? '${widget.template.name} (mine)' : widget.template.name,
  );
  late final _subject = TextEditingController(text: widget.template.subject);
  late final _body = (widget.template.blocksJson ?? '').length > 2
      ? BodyEditorController(mode: BodyMode.builder, blocksJson: widget.template.blocksJson)
      : BodyEditorController(mode: (widget.template.html ?? '').isEmpty ? BodyMode.builder : BodyMode.html, html: widget.template.html);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showToast(context, 'Give the template a name');
    setState(() => _saving = true);
    final html = _body.render();
    try {
      await ref
          .read(templatesProvider.notifier)
          .save(
            MailTemplate(
              id: widget.template.id,
              name: _name.text.trim(),
              subject: _subject.text,
              html: html,
              blocksJson: _body.mode == BodyMode.builder ? _body.toJson()['blocks'] : null,
              variables: findVariables([_subject.text, html]),
            ),
          );
      Feel.commit.ring();
      if (mounted) {
        showToast(context, 'Template saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconPress(icon: LucideIcons.x, label: 'Close', onTap: () => context.pop()),
      title: const Text('Template'),
      actions: [
        IconPress(icon: LucideIcons.eye, label: 'Preview', onTap: () => showPreview(context, _body.render())),
        _saving
            ? const Padding(padding: EdgeInsets.all(12), child: QuireSpinner(size: 22))
            : IconPress(icon: LucideIcons.check, label: 'Save', color: AppColors.accentBright, onTap: _save),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Use {{first_name}}, {{company}} or any {{name}} and you will be asked to fill them in before sending.',
            style: AppText.docMeta.copyWith(color: AppColors.inkFaint),
          ),
        ),
        Expanded(
          child: BodyEditor(controller: _body, uploadImage: () => pickAndUploadImage(context, ref)),
        ),
      ],
    ),
  );
}
