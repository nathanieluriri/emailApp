import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api/api_client.dart';
import '../core/quire/brand/quire_mark.dart';
import '../core/quire/painting/page_style.dart' show kThumbnailAspect;
import '../core/quire/painting/thumbnail_painter.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/quire/widgets/quire_spinner.dart';
import '../core/widgets.dart';
import 'attachments.dart';
import 'models.dart';
import 'quire.dart';

/// A file's kind, in Quire's colours and, for the formats Quire reads, with the letters of Quire's type mark.
enum FileKind {
  pdf(LucideIcons.fileText, Color(0xFFE8544A), 'PDF'),
  doc(LucideIcons.fileType, Color(0xFF4285F4), 'DOC'),
  sheet(LucideIcons.fileSpreadsheet, Color(0xFF21A366), 'XLS'),
  csv(LucideIcons.fileSpreadsheet, Color(0xFFC9832B), 'CSV'),
  slides(LucideIcons.presentation, Color(0xFFD24726), 'PPT'),
  markdown(LucideIcons.fileText, Color(0xFFB39DDB), 'MD'),
  image(LucideIcons.image, Color(0xFFE8544A)),
  archive(LucideIcons.fileArchive, Color(0xFF938F99)),
  audio(LucideIcons.fileAudio, Color(0xFFB39DDB)),
  video(LucideIcons.fileVideo, Color(0xFFB39DDB)),
  other(LucideIcons.file, Color(0xFF938F99));

  const FileKind(this.icon, this.color, [this.mark]);
  final IconData icon;
  final Color color;
  final String? mark;

  static FileKind of(String type, String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (quireFormat(name, type)) {
      case 'pdf':
        return pdf;
      case 'docx':
        return doc;
      case 'xlsx':
        return sheet;
      case 'pptx':
        return slides;
      case 'csv':
        return csv;
      case 'md':
        return markdown;
    }
    bool any(List<String> words) => words.any((w) => type.contains(w) || ext == w);
    if (type.startsWith('image/')) return image;
    if (type.startsWith('audio/')) return audio;
    if (type.startsWith('video/')) return video;
    if (any(['spreadsheet', 'excel', 'xls', 'ods'])) return sheet;
    if (any(['presentation', 'powerpoint', 'ppt', 'pptx', 'odp'])) return slides;
    if (any(['zip', 'rar', '7z', 'tar', 'gzip', 'gz'])) return archive;
    if (any(['word', 'msword', 'doc', 'docx', 'odt', 'rtf', 'text/', 'txt'])) return doc;
    return other;
  }
}

/// Gmail's attachment cards: one fills the width, several sit two to a row at the shape of Quire's desk cards.
class AttachmentCards extends StatelessWidget {
  const AttachmentCards({super.key, required this.attachments});
  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (attachments.length == 1) {
        return AttachmentCard(attachment: attachments.first, previewHeight: box.maxWidth * 0.6);
      }
      final width = (box.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in attachments)
            SizedBox(
              width: width,
              child: AttachmentCard(attachment: a, previewHeight: width / kThumbnailAspect),
            ),
        ],
      );
    },
  );
}

/// A file attached to mail: a preview on top, and its type, name and Download (or Remove, while writing) below.
class AttachmentCard extends ConsumerStatefulWidget {
  const AttachmentCard({super.key, required this.attachment, required this.previewHeight, this.bytes, this.onRemove});
  final Attachment attachment;
  final double previewHeight;

  /// The file itself, for mail still being written; otherwise it comes from the server.
  final Uint8List? bytes;
  final VoidCallback? onRemove;

  @override
  ConsumerState<AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends ConsumerState<AttachmentCard> {
  bool _busy = false;
  Preview? _local;

  Attachment get _a => widget.attachment;

  @override
  void initState() {
    super.initState();
    final bytes = widget.bytes;
    if (bytes != null) {
      previewOfBytes(bytes, name: _a.filename, type: _a.mimeType).then((p) {
        if (mounted) setState(() => _local = p);
      });
    }
  }

  /// Pictures open here; anything Quire reads offers Quire when it is on the phone; the rest goes to another app.
  Future<void> _tap() async {
    if (_a.isImage) return _run(_view);
    final quire = quireFormat(_a.filename, _a.mimeType) != null && await ref.read(quireInstalledProvider.future);
    if (!mounted) return;
    if (!quire) return _run(_launch);
    final picked = await showQuireSheet<int>(
      context,
      (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetTitle(_a.filename),
          SheetRow(label: 'Open in Quire', leading: const _QuireGlyph(), onTap: () => Navigator.pop(sheet, 0)),
          SheetRow(label: 'Open with another app', icon: LucideIcons.externalLink, onTap: () => Navigator.pop(sheet, 1)),
          if (widget.onRemove == null) SheetRow(label: 'Download', icon: LucideIcons.download, onTap: () => Navigator.pop(sheet, 2)),
          const SizedBox(height: 8),
        ],
      ),
    );
    switch (picked) {
      case 0:
        await _run(_quire);
      case 1:
        await _run(_launch);
      case 2:
        await _run(_download);
    }
  }

  Future<void> _quire(Uint8List bytes) async {
    final opened = await openInQuire(bytes, id: _a.id, name: _a.filename, type: _a.mimeType);
    if (!opened && mounted) showToast(context, 'Quire could not open ${_a.filename}');
  }

  Future<void> _run(Future<void> Function(Uint8List bytes) action) async {
    setState(() => _busy = true);
    try {
      await action(widget.bytes ?? await (await ref.read(attachmentFileProvider(_a.id).future)).readAsBytes());
    } catch (e) {
      if (mounted) showToast(context, 'Could not get ${_a.filename}: ${ApiException.from(e).message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(Uint8List bytes) async {
    await showQuireSheet(
      context,
      (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetTitle(_a.filename),
            Flexible(
              child: InteractiveViewer(
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes)),
              ),
            ),
            const SizedBox(height: 12),
            PillButton(label: 'Open in another app', icon: LucideIcons.externalLink, onTap: () => _launch(bytes)),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_a.id}-${_a.filename.replaceAll(RegExp(r'[/\\]'), '_')}');
    await file.writeAsBytes(bytes);
    final result = await OpenFilex.open(file.path, type: _a.mimeType);
    if (result.type != ResultType.done && mounted) showToast(context, result.message);
  }

  Future<void> _download(Uint8List bytes) async {
    final saved = await FilePicker.saveFile(fileName: _a.filename, bytes: bytes, mimeType: _a.mimeType);
    if (saved != null && mounted) showToast(context, 'Saved ${_a.filename}');
  }

  @override
  Widget build(BuildContext context) {
    final kind = FileKind.of(_a.mimeType, _a.filename);
    final preview = widget.bytes != null
        ? _local
        : ref.watch(attachmentPreviewProvider((id: _a.id, name: _a.filename, type: _a.mimeType, size: _a.size))).value;
    final pixels = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
    return PaperPress(
      onTap: _busy ? null : _tap,
      semanticLabel: 'Open ${_a.filename}',
      washRadius: 14,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            SizedBox(
              height: widget.previewHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _TypeArt(kind: kind, name: _a.filename),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
                    child: switch (preview) {
                      PicturePreview(:final image) => Image(
                        key: ValueKey(image),
                        image: ResizeImage.resizeIfNeeded(pixels, null, image),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        frameBuilder: (context, child, frame, synchronous) => AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: synchronous ? Duration.zero : const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          child: child,
                        ),
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      PagePreview(:final page) => CustomPaint(key: ValueKey(page), painter: ThumbnailPainter(page)),
                      null => const SizedBox.shrink(),
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  _busy ? const QuireSpinner(size: 20) : _KindMark(kind: kind, name: _a.filename, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FileName(_a.filename, style: AppText.label.copyWith(color: AppColors.ink, fontSize: 14)),
                  ),
                  widget.onRemove != null
                      ? IconPress(icon: LucideIcons.x, label: 'Remove ${_a.filename}', size: 20, onTap: widget.onRemove)
                      : IconPress(
                          icon: LucideIcons.download,
                          label: 'Download ${_a.filename}',
                          size: 20,
                          onTap: _busy ? null : () => _run(_download),
                        ),
                  const SizedBox(width: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The type of a file that has no picture to show yet: Quire's type mark, or an icon and the extension.
class _TypeArt extends StatelessWidget {
  const _TypeArt({required this.kind, required this.name});
  final FileKind kind;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : '';
    return ColoredBox(
      color: AppColors.ink.withValues(alpha: 0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _KindMark(kind: kind, name: name, size: kind.mark == null ? 34 : 40),
          if (kind.mark == null && ext.isNotEmpty && ext.length <= 5) ...[
            const SizedBox(height: 6),
            Text(ext, style: AppText.docMeta.copyWith(color: AppColors.inkSoft, letterSpacing: 0.8)),
          ],
        ],
      ),
    );
  }
}

/// Quire's type mark for the formats it reads: the format's letters on its colour, as on Quire's desk. Other files
/// keep an icon.
class _KindMark extends StatelessWidget {
  const _KindMark({required this.kind, required this.name, required this.size});
  final FileKind kind;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = kind.mark;
    if (mark == null) return Icon(kind.icon, size: size * 20 / 22, color: kind.color);
    final letters = kind == FileKind.markdown && name.toLowerCase().endsWith('.txt') ? 'TXT' : mark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: kind.color, borderRadius: BorderRadius.circular(8 * size / 30)),
      child: Text(
        letters,
        maxLines: 1,
        style: TextStyle(
          inherit: false,
          fontFamily: 'Inter',
          fontSize: 10 * size / 30,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: const Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}

/// Quire's own mark, four panes, for the row that opens a file in Quire.
class _QuireGlyph extends StatelessWidget {
  const _QuireGlyph();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GlyphPainter(AppColors.accentBright));
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final box = QuireMark.ink;
    final scale = size.shortestSide / box.longestSide;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-box.center.dx, -box.center.dy)
      ..drawPath(QuireMark.whole, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color;
}

/// A file name shortened in the middle, so its ending and extension stay readable: "Screens…me.jpg".
class FileName extends StatelessWidget {
  const FileName(this.name, {super.key, required this.style});
  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        bool fits(String s) =>
            (TextPainter(
              text: TextSpan(text: s, style: style),
              textDirection: TextDirection.ltr,
              textScaler: scaler,
              maxLines: 1,
            )..layout()).width <=
            box.maxWidth;
        var shown = name;
        if (!fits(name)) {
          final dot = name.lastIndexOf('.');
          final cut = math.max(0, (dot > 0 ? dot : name.length) - 2);
          final tail = name.substring(cut);
          var lo = 0;
          var hi = cut;
          while (lo < hi) {
            final mid = (lo + hi + 1) ~/ 2;
            fits('${name.substring(0, mid)}…$tail') ? lo = mid : hi = mid - 1;
          }
          shown = '${name.substring(0, lo)}…$tail';
        }
        return Text(shown, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: style);
      },
    );
  }
}
