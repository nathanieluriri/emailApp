import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../builder/blocks.dart';
import '../builder/builder_editor.dart';
import '../builder/html_export.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/widgets.dart';
import 'html_tools.dart';
import 'preview.dart';

enum BodyMode { rich, html, builder }

/// Holds one body in all three shapes; only the current mode's shape is sent.
class BodyEditorController extends ChangeNotifier {
  BodyEditorController({this.mode = BodyMode.rich, String? delta, String? html, String? blocksJson, this.fragment = false})
    : quill = QuillController(
        document: delta == null ? Document() : Document.fromJson(jsonDecode(delta) as List),
        selection: const TextSelection.collapsed(offset: 0),
      ),
      html = TextEditingController(text: html),
      blocks = decodeBlocks(blocksJson) {
    quill.addListener(notifyListeners);
    this.html.addListener(notifyListeners);
  }

  factory BodyEditorController.fromJson(Map<String, dynamic> json, {bool fragment = false}) => BodyEditorController(
    mode: BodyMode.values.byName(json['mode'] ?? 'rich'),
    delta: json['delta'],
    html: json['html'],
    blocksJson: json['blocks'],
    fragment: fragment,
  );

  BodyMode mode;
  final bool fragment;
  final QuillController quill;
  final TextEditingController html;
  List<Block> blocks;

  void setMode(BodyMode m) {
    mode = m;
    notifyListeners();
  }

  void setBlocks(List<Block> b) {
    blocks = b;
    notifyListeners();
  }

  void loadHtml(String value) {
    html.text = value;
    mode = BodyMode.html;
    notifyListeners();
  }

  void loadBlocks(String json) {
    blocks = decodeBlocks(json);
    mode = BodyMode.builder;
    notifyListeners();
  }

  bool get isEmpty => switch (mode) {
    BodyMode.rich => quill.document.toPlainText().trim().isEmpty,
    BodyMode.html => html.text.trim().isEmpty,
    BodyMode.builder => blocks.isEmpty,
  };

  String render() => switch (mode) {
    BodyMode.rich => deltaToHtml(quill.document.toDelta().toJson()),
    BodyMode.html => autoFixHtml(html.text),
    BodyMode.builder => fragment ? exportFragment(blocks) : exportBlocks(blocks),
  };

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'delta': jsonEncode(quill.document.toDelta().toJson()),
    'html': html.text,
    'blocks': encodeBlocks(blocks),
  };

  @override
  void dispose() {
    quill.dispose();
    html.dispose();
    super.dispose();
  }
}

class BodyEditor extends StatefulWidget {
  const BodyEditor({super.key, required this.controller, this.uploadImage});
  final BodyEditorController controller;
  final Future<String?> Function()? uploadImage;

  @override
  State<BodyEditor> createState() => _BodyEditorState();
}

class _BodyEditorState extends State<BodyEditor> {
  BodyEditorController get c => widget.controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: GooSegmented<BodyMode>(
            values: BodyMode.values,
            labels: const ['Rich text', 'Paste HTML', 'Builder'],
            selected: c.mode,
            onChanged: c.setMode,
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(c.mode),
              child: switch (c.mode) {
                BodyMode.rich => _RichEditor(controller: c.quill),
                BodyMode.html => _HtmlEditor(controller: c.html),
                BodyMode.builder => BuilderEditor(blocks: c.blocks, onChanged: c.setBlocks, uploadImage: widget.uploadImage),
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class _RichEditor extends StatelessWidget {
  const _RichEditor({required this.controller});
  final QuillController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      QuillSimpleToolbar(
        controller: controller,
        config: const QuillSimpleToolbarConfig(
          multiRowsDisplay: false,
          showDividers: false,
          showFontFamily: false,
          showFontSize: false,
          showSmallButton: false,
          showInlineCode: false,
          showBackgroundColorButton: false,
          showClearFormat: false,
          showAlignmentButtons: true,
          showJustifyAlignment: false,
          showListCheck: false,
          showCodeBlock: false,
          showIndent: false,
          showSearchButton: false,
          showSubscript: false,
          showSuperscript: false,
          showUndo: false,
          showRedo: false,
        ),
      ),
      Expanded(
        child: QuillEditor.basic(
          controller: controller,
          config: const QuillEditorConfig(placeholder: 'Compose email', padding: EdgeInsets.fromLTRB(20, 12, 20, 24)),
        ),
      ),
    ],
  );
}

class _HtmlEditor extends StatefulWidget {
  const _HtmlEditor({required this.controller});
  final TextEditingController controller;

  @override
  State<_HtmlEditor> createState() => _HtmlEditorState();
}

class _HtmlEditorState extends State<_HtmlEditor> {
  bool _preview = false;
  late String _shown = widget.controller.text;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _shown != widget.controller.text) setState(() => _shown = widget.controller.text);
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) {
      if (mounted) showToast(context, 'The clipboard is empty');
      return;
    }
    Feel.commit.ring();
    widget.controller.text = data.text!;
  }

  void _fix() {
    Feel.commit.ring();
    widget.controller.text = autoFixHtml(widget.controller.text);
    showToast(context, 'Scripts removed and CSS inlined');
  }

  @override
  Widget build(BuildContext context) {
    final editor = TextField(
      controller: widget.controller,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: AppText.code.copyWith(color: AppColors.ink),
      decoration: const InputDecoration(hintText: 'Paste your HTML email here'),
    );
    final preview = _shown.trim().isEmpty
        ? Center(
            child: Text('The preview shows up here', style: AppText.bodyTight.copyWith(color: AppColors.inkFaint)),
          )
        : PreviewPane(html: autoFixHtml(_shown));
    return LayoutBuilder(
      builder: (context, box) {
        final split = box.maxWidth >= 600;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    PillButton(label: 'Paste from clipboard', icon: LucideIcons.clipboardPaste, filled: false, onTap: _paste),
                    const SizedBox(width: 8),
                    PillButton(label: 'Auto-fix', icon: LucideIcons.wandSparkles, filled: false, onTap: _fix),
                    if (!split) ...[
                      const SizedBox(width: 8),
                      PillButton(
                        label: _preview ? 'Edit' : 'Preview',
                        icon: _preview ? LucideIcons.code : LucideIcons.eye,
                        filled: false,
                        onTap: () => setState(() => _preview = !_preview),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: split
                    ? Row(
                        children: [
                          Expanded(child: editor),
                          const SizedBox(width: 8),
                          Expanded(child: preview),
                        ],
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _preview ? KeyedSubtree(key: const ValueKey('p'), child: preview) : editor,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
