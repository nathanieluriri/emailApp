import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../accounts/accounts_controller.dart';
import '../core/quire/format/document_loader.dart';
import '../core/quire/model/document.dart';
import '../core/quire/painting/thumbnail_painter.dart';
import 'quire.dart';

/// Larger attachments are not downloaded just to draw a preview; they show their type until opened.
const _previewLimit = 10 * 1024 * 1024;
const _files = MethodChannel('quirepost/files');

/// An attachment's file, downloaded once into the app's cache, which the phone may clear when it needs space.
final attachmentFileProvider = FutureProvider.family<File, String>((ref, id) async {
  final account = ref.watch(activeAccountProvider);
  final dir = Directory('${(await getApplicationCacheDirectory()).path}/attachments/${account?.id}');
  final file = File('${dir.path}/$id');
  if (await file.exists()) return file;
  final bytes = await ref.read(apiProvider).attachment(id);
  await dir.create(recursive: true);
  final part = await File('${file.path}.part').writeAsBytes(bytes, flush: true);
  return part.rename(file.path);
});

/// What a card shows of a file: a picture, or a page Quire's painter recorded.
sealed class Preview {
  const Preview();
}

/// A photo, or a PDF's first page as the phone's own renderer draws it, as Quire's reader does.
class PicturePreview extends Preview {
  const PicturePreview(this.image);
  final ImageProvider image;
}

/// A Word, Excel, PowerPoint, CSV or Markdown file's first screen, recorded by Quire's thumbnail painter.
class PagePreview extends Preview {
  const PagePreview(this.page);
  final ThumbnailPicture page;
}

typedef AttachmentKey = ({String id, String name, String type, int size});

bool previewable(String name, String type, int size) =>
    size <= _previewLimit && (type.startsWith('image/') || quireFormat(name, type) != null);

final attachmentPreviewProvider = FutureProvider.family<Preview?, AttachmentKey>((ref, a) async {
  if (!previewable(a.name, a.type, a.size)) return null;
  final file = await ref.watch(attachmentFileProvider(a.id).future);
  if (a.type.startsWith('image/')) return PicturePreview(FileImage(file));
  if (quireFormat(a.name, a.type) == 'pdf') return _pdfPage(file);
  return _page(await file.readAsBytes(), a.name);
});

/// The same preview for a file still being written, from its bytes.
Future<Preview?> previewOfBytes(Uint8List bytes, {required String name, required String type}) async {
  if (!previewable(name, type, bytes.length)) return null;
  if (type.startsWith('image/')) return PicturePreview(MemoryImage(bytes));
  if (quireFormat(name, type) != 'pdf') return _page(bytes, name);
  final dir = Directory('${(await getTemporaryDirectory()).path}/previews');
  await dir.create(recursive: true);
  final file = await File('${dir.path}/${identityHashCode(bytes)}.pdf').writeAsBytes(bytes, flush: true);
  return _pdfPage(file);
}

Future<Preview> _page(Uint8List bytes, String name) async {
  final document = await compute(_read, (bytes, name));
  return PagePreview(document == null ? recordEmptyThumbnail() : thumbnailOf(document));
}

QuireDocument? _read((Uint8List, String) file) {
  final loaded = DocumentLoader.load(file.$1, file.$2);
  return loaded.failed ? null : loaded.document;
}

Future<Preview?> _pdfPage(File file) async {
  final page = File('${file.path}.png');
  if (!await page.exists()) {
    try {
      final png = await _files.invokeMethod<Uint8List>('pdfPage', {'path': file.path, 'width': 1080});
      if (png == null) return null;
      await page.writeAsBytes(png, flush: true);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
  return PicturePreview(FileImage(page));
}
