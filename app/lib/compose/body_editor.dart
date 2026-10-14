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
import '../core/quire/widgets/press_fade.dart';
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

  bool get isRichEmpty => quill.document.toPlainText().trim().isEmpty;

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
                BodyMode.rich => RichEditor(controller: c.quill),
                BodyMode.html => HtmlCodeEditor(controller: c.html),
                BodyMode.builder => BuilderEditor(blocks: c.blocks, onChanged: c.setBlocks, uploadImage: widget.uploadImage),
              },
            ),
          ),
        ),
      ],
    ),
  );
}

/// Quill needs one focus node and scroll controller for its whole life; making them in build drops the keyboard on every keystroke.
class RichEditor extends StatefulWidget {
  const RichEditor({
    super.key,
    this.focusNode,
    required this.controller,
    this.toolbar = true,
    this.scrollable = true,
    this.placeholder = 'Compose email',
    this.padding,
  });
  final FocusNode? focusNode;
  final QuillController controller;
  final bool toolbar;
  final bool scrollable;
  final String placeholder;
  final EdgeInsets? padding;

  @override
  State<RichEditor> createState() => _RichEditorState();
}

class _RichEditorState extends State<RichEditor> {
  late final _focus = widget.focusNode ?? FocusNode();
  final _scroll = ScrollController();

  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = QuillEditor(
      controller: widget.controller,
      focusNode: _focus,
      scrollController: _scroll,
      config: QuillEditorConfig(
        placeholder: widget.placeholder,
        scrollable: widget.scrollable,
        expands: false,
        padding: widget.padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 24),
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            AppText.pageBody.copyWith(color: AppColors.ink),
            HorizontalSpacing.zero,
            const VerticalSpacing(0, 6),
            VerticalSpacing.zero,
            null,
          ),
          placeHolder: DefaultTextBlockStyle(
            AppText.pageBody.copyWith(color: AppColors.inkFaint),
            HorizontalSpacing.zero,
            VerticalSpacing.zero,
            VerticalSpacing.zero,
            null,
          ),
        ),
      ),
    );
    if (!widget.toolbar) return editor;
    return Column(
      children: [
        FormatBar(controller: widget.controller),
        Expanded(child: editor),
      ],
    );
  }
}

/// The few formats an email needs, in one quiet row. Each lights up while the cursor sits in that format.
class FormatBar extends StatelessWidget {
  const FormatBar({super.key, required this.controller});
  final QuillController controller;

  void _toggle(Attribute attribute) {
    Feel.tap.ring();
    final on = controller.getSelectionStyle().attributes[attribute.key]?.value == attribute.value;
    controller.formatSelection(on ? Attribute.clone(attribute, null) : attribute);
  }

  Future<void> _link(BuildContext context) async {
    final current = controller.getSelectionStyle().attributes[Attribute.link.key]?.value as String?;
    final url = await promptText(context, title: 'Link', initial: current ?? 'https://', action: 'Add link', hint: 'https://');
    if (url == null) return;
    controller.formatSelection(url.isEmpty || url == 'https://' ? Attribute.clone(Attribute.link, null) : LinkAttribute(url));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final attrs = controller.getSelectionStyle().attributes;
      Widget button(IconData icon, String label, Attribute attribute) =>
          _FormatButton(icon: icon, label: label, active: attrs[attribute.key]?.value == attribute.value, onTap: () => _toggle(attribute));
      return SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            button(LucideIcons.bold, 'Bold', Attribute.bold),
            button(LucideIcons.italic, 'Italic', Attribute.italic),
            button(LucideIcons.underline, 'Underline', Attribute.underline),
            button(LucideIcons.list, 'Bulleted list', Attribute.ul),
            button(LucideIcons.listOrdered, 'Numbered list', Attribute.ol),
            button(LucideIcons.textQuote, 'Quote', Attribute.blockQuote),
            _FormatButton(
              icon: LucideIcons.link,
              label: 'Link',
              active: attrs.containsKey(Attribute.link.key),
              onTap: () => _link(context),
            ),
          ],
        ),
      );
    },
  );
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    child: PaperPress(
      onTap: onTap,
      feel: Feel.none,
      semanticLabel: label,
      washRadius: 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        decoration: BoxDecoration(color: active ? AppColors.accentMuted : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 19, color: active ? AppColors.accentBright : AppColors.inkSoft),
      ),
    ),
  );
}

class HtmlCodeEditor extends StatefulWidget {
  const HtmlCodeEditor({super.key, required this.controller});
  final TextEditingController controller;

  @override
  State<HtmlCodeEditor> createState() => _HtmlEditorState();
}

class _HtmlEditorState extends State<HtmlCodeEditor> {
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

/// HTML and the block designer live here, off the everyday compose screen.
class AdvancedEditorScreen extends StatelessWidget {
  const AdvancedEditorScreen({super.key, required this.controller, this.uploadImage});
  final BodyEditorController controller;
  final Future<String?> Function()? uploadImage;

  @override
  Widget build(BuildContext context) {
    final html = controller.mode == BodyMode.html;
    return Scaffold(
      appBar: AppBar(
        leading: IconPress(icon: LucideIcons.arrowLeft, label: 'Back to email', onTap: () => Navigator.pop(context)),
        title: Text(html ? 'HTML editor' : 'Email designer'),
        actions: [
          IconPress(icon: LucideIcons.eye, label: 'Preview', onTap: () => showPreview(context, controller.render())),
          IconPress(icon: LucideIcons.check, label: 'Done', color: AppColors.accentBright, onTap: () => Navigator.pop(context)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: html
            ? HtmlCodeEditor(controller: controller.html)
            : ListenableBuilder(
                listenable: controller,
                builder: (_, _) => BuilderEditor(blocks: controller.blocks, onChanged: controller.setBlocks, uploadImage: uploadImage),
              ),
      ),
    );
  }
}
