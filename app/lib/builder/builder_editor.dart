import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'blocks.dart';

const _blockIcons = {
  BlockType.heading: LucideIcons.heading,
  BlockType.text: LucideIcons.text,
  BlockType.button: LucideIcons.squareMousePointer,
  BlockType.image: LucideIcons.image,
  BlockType.divider: LucideIcons.minus,
  BlockType.spacer: LucideIcons.moveVertical,
  BlockType.columns: LucideIcons.columns2,
  BlockType.social: LucideIcons.share2,
  BlockType.footer: LucideIcons.panelBottom,
};

/// Blocks you drag in from the palette, reorder by their handle and tap to edit.
class BuilderEditor extends StatefulWidget {
  const BuilderEditor({super.key, required this.blocks, required this.onChanged, this.uploadImage});
  final List<Block> blocks;
  final ValueChanged<List<Block>> onChanged;
  final Future<String?> Function()? uploadImage;

  @override
  State<BuilderEditor> createState() => _BuilderEditorState();
}

class _BuilderEditorState extends State<BuilderEditor> {
  late List<Block> _blocks = [...widget.blocks];
  bool _hovering = false;

  @override
  void didUpdateWidget(BuilderEditor old) {
    super.didUpdateWidget(old);
    if (old.blocks != widget.blocks) _blocks = [...widget.blocks];
  }

  void _commit(List<Block> next) {
    setState(() => _blocks = next);
    widget.onChanged(next);
  }

  void _add(BlockType type, [int? at]) {
    Feel.commit.ring();
    final next = [..._blocks]..insert(at ?? _blocks.length, Block(type: type));
    _commit(next);
  }

  Future<void> _menu(Block b) async {
    final i = _blocks.indexOf(b);
    await showQuireSheet(
      context,
      (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetTitle(blockLabels[b.type]!),
          SheetRow(
            label: 'Edit',
            icon: LucideIcons.pencil,
            onTap: () {
              Navigator.pop(sheet);
              _edit(b);
            },
          ),
          SheetRow(
            label: 'Duplicate',
            icon: LucideIcons.copy,
            onTap: () {
              Navigator.pop(sheet);
              _commit([..._blocks]..insert(i + 1, b.copy()));
            },
          ),
          SheetRow(
            label: 'Delete',
            icon: LucideIcons.trash2,
            destructive: true,
            onTap: () {
              Navigator.pop(sheet);
              _commit([..._blocks]..removeAt(i));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _edit(Block b) async {
    await showQuireSheet(
      context,
      (_) => BlockEditorSheet(block: b, uploadImage: widget.uploadImage, onChanged: () => _commit([..._blocks])),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: DragTarget<BlockType>(
          onWillAcceptWithDetails: (_) {
            setState(() => _hovering = true);
            return true;
          },
          onLeave: (_) => setState(() => _hovering = false),
          onAcceptWithDetails: (d) {
            setState(() => _hovering = false);
            _add(d.data);
          },
          builder: (context, _, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _hovering ? AppColors.accentBright : AppColors.hairline, width: _hovering ? 2 : 1),
            ),
            child: _blocks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Drag a block here, or tap one below.',
                        textAlign: TextAlign.center,
                        style: AppText.bodyTight.copyWith(color: const Color(0xFF79747E)),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _blocks.length,
                    onReorderStart: (_) => Feel.turn.ring(),
                    onReorderEnd: (_) => Feel.tap.ring(),
                    proxyDecorator: (child, i, animation) => AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => Transform.scale(
                        scale: 1 + 0.03 * Curves.easeOut.transform(animation.value),
                        child: Material(color: Colors.transparent, child: child),
                      ),
                      child: child,
                    ),
                    onReorderItem: (from, to) {
                      final next = [..._blocks];
                      next.insert(to, next.removeAt(from));
                      _commit(next);
                    },
                    itemBuilder: (context, i) {
                      final b = _blocks[i];
                      return PaperPress(
                        key: ValueKey(b.id),
                        onTap: () => _edit(b),
                        onLongPress: () => _menu(b),
                        washRadius: 8,
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                                child: Icon(LucideIcons.gripVertical, size: 18, color: Color(0xFFB0AAB8)),
                              ),
                            ),
                            Expanded(child: BlockPreview(block: b)),
                            const SizedBox(width: 8),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
      SizedBox(
        height: 76,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          children: [
            for (final type in BlockType.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LongPressDraggable<BlockType>(
                  data: type,
                  onDragStarted: () => Feel.turn.ring(),
                  feedback: Material(
                    color: Colors.transparent,
                    child: _PaletteChip(type: type, lifted: true),
                  ),
                  childWhenDragging: Opacity(opacity: 0.4, child: _PaletteChip(type: type)),
                  child: PaperPress(
                    onTap: () => _add(type),
                    semanticLabel: 'Add ${blockLabels[type]}',
                    child: _PaletteChip(type: type),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({required this.type, this.lifted = false});
  final BlockType type;
  final bool lifted;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: lifted ? 1.08 : 1,
    duration: const Duration(milliseconds: 160),
    child: Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: lifted ? AppColors.accentMuted : AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_blockIcons[type], size: 20, color: AppColors.ink),
          const SizedBox(height: 4),
          Text(blockLabels[type]!, style: AppText.typeMark.copyWith(color: AppColors.inkSoft)),
        ],
      ),
    ),
  );
}

Color _hex(String s) => parseHex(s, const Color(0xFF1C1B1F));

TextAlign _align(String a) => switch (a) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  _ => TextAlign.left,
};

Alignment _alignment(String a) => switch (a) {
  'center' => Alignment.center,
  'right' => Alignment.centerRight,
  _ => Alignment.centerLeft,
};

/// A close Flutter rendering of a block, so the canvas reads like the email it exports.
class BlockPreview extends StatelessWidget {
  const BlockPreview({super.key, required this.block});
  final Block block;

  @override
  Widget build(BuildContext context) {
    final b = block;
    TextStyle style([FontWeight w = FontWeight.w400]) =>
        TextStyle(fontFamily: 'Inter', fontSize: b.numOf('fontSize').toDouble(), color: _hex(b.str('color')), fontWeight: w, height: 1.4);
    final pad = EdgeInsets.symmetric(vertical: b.numOf('padding').toDouble() / 2, horizontal: 8);
    return switch (b.type) {
      BlockType.heading => Padding(
        padding: pad,
        child: Text(b.str('text'), textAlign: _align(b.str('align')), style: style(FontWeight.w700)),
      ),
      BlockType.text || BlockType.footer => Padding(
        padding: pad,
        child: Text(b.str('text'), textAlign: _align(b.str('align')), style: style()),
      ),
      BlockType.button => Padding(
        padding: pad,
        child: Align(
          alignment: _alignment(b.str('align')),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(color: _hex(b.str('color')), borderRadius: BorderRadius.circular(b.numOf('radius').toDouble())),
            child: Text(b.str('text'), style: style(FontWeight.w600).copyWith(color: _hex(b.str('textColor')))),
          ),
        ),
      ),
      BlockType.image => Padding(
        padding: pad,
        child: b.str('src').isEmpty
            ? Container(
                height: 120,
                decoration: BoxDecoration(color: const Color(0xFFF3EFF7), borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Icon(LucideIcons.imagePlus, color: Color(0xFF79747E))),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(b.numOf('radius').toDouble()),
                child: Image.network(b.str('src'), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(LucideIcons.imageOff)),
              ),
      ),
      BlockType.divider => Padding(
        padding: pad,
        child: Container(height: 1, color: _hex(b.str('color'))),
      ),
      BlockType.spacer => SizedBox(
        height: b.numOf('height').toDouble(),
        child: const Center(child: Divider(color: Color(0x22000000), indent: 40, endIndent: 40)),
      ),
      BlockType.columns => Padding(
        padding: pad,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(b.str('left'), style: style())),
            const SizedBox(width: 12),
            Expanded(child: Text(b.str('right'), style: style())),
          ],
        ),
      ),
      BlockType.social => Padding(
        padding: pad,
        child: Text(
          ['website', 'linkedin', 'x', 'instagram', 'facebook'].where((k) => b.str(k).isNotEmpty).join('  ·  ').ifEmpty('Add your links'),
          textAlign: _align(b.str('align')),
          style: style(FontWeight.w600).copyWith(fontSize: 13),
        ),
      ),
    };
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class BlockEditorSheet extends StatefulWidget {
  const BlockEditorSheet({super.key, required this.block, required this.onChanged, this.uploadImage});
  final Block block;
  final VoidCallback onChanged;
  final Future<String?> Function()? uploadImage;

  @override
  State<BlockEditorSheet> createState() => _BlockEditorSheetState();
}

class _BlockEditorSheetState extends State<BlockEditorSheet> {
  Block get b => widget.block;

  void _set(String key, Object value) {
    setState(() => b.props[key] = value);
    widget.onChanged();
  }

  Widget _field(String key, String label, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      initialValue: b.str(key),
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => _set(key, v),
    ),
  );

  Widget _slider(String key, String label, double min, double max) => Row(
    children: [
      SizedBox(
        width: 96,
        child: Text(label, style: AppText.label.copyWith(color: AppColors.inkSoft)),
      ),
      Expanded(
        child: Slider(
          value: b.numOf(key).toDouble().clamp(min, max),
          min: min,
          max: max,
          divisions: (max - min).round(),
          activeColor: AppColors.accentBright,
          onChanged: (v) {
            if (v.round() != b.numOf(key)) Feel.tap.ring();
            _set(key, v.round());
          },
        ),
      ),
      SizedBox(
        width: 32,
        child: Text('${b.numOf(key)}', style: AppText.label.copyWith(color: AppColors.ink)),
      ),
    ],
  );

  Widget _colors(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in brandPalette)
              PaperPress(
                onTap: () => _set(key, c),
                washRadius: 16,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hex(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: b.str(key).toUpperCase() == c ? AppColors.accentBright : AppColors.hairline,
                      width: b.str(key).toUpperCase() == c ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final has = b.props.containsKey;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(blockLabels[b.type]!),
          if (has('text')) _field('text', 'Text', lines: b.type == BlockType.heading || b.type == BlockType.button ? 1 : 3),
          if (has('left')) _field('left', 'Left column', lines: 3),
          if (has('right')) _field('right', 'Right column', lines: 3),
          if (has('url')) _field('url', 'Link'),
          if (b.type == BlockType.image) ...[
            _field('src', 'Image URL'),
            if (widget.uploadImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PillButton(
                  label: 'Upload image',
                  icon: LucideIcons.upload,
                  filled: false,
                  onTap: () async {
                    final url = await widget.uploadImage!();
                    if (url != null) _set('src', url);
                  },
                ),
              ),
            _field('alt', 'Description'),
            _field('link', 'Opens when tapped'),
          ],
          if (b.type == BlockType.social)
            for (final k in ['website', 'linkedin', 'x', 'instagram', 'facebook']) _field(k, k[0].toUpperCase() + k.substring(1)),
          if (has('align')) ...[
            const SizedBox(height: 4),
            GooSegmented<String>(
              values: const ['left', 'center', 'right'],
              labels: const ['Left', 'Centre', 'Right'],
              selected: b.str('align'),
              onChanged: (v) => _set('align', v),
            ),
            const SizedBox(height: 12),
          ],
          if (has('color')) _colors('color', b.type == BlockType.button ? 'Button colour' : 'Colour'),
          if (has('textColor')) _colors('textColor', 'Label colour'),
          if (has('fontSize')) _slider('fontSize', 'Font size', 10, 40),
          if (has('padding')) _slider('padding', 'Padding', 0, 48),
          if (has('radius')) _slider('radius', 'Roundness', 0, 30),
          if (has('height')) _slider('height', 'Height', 4, 96),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: PillButton(label: 'Done', onTap: () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }
}
