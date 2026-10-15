import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../accounts/accounts_controller.dart';

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

typedef AttachmentKey = ({String id, String type, int size});

/// What a card shows of an attachment: the picture itself or a PDF's first page, else null for its type icon.
final attachmentPreviewProvider = FutureProvider.family<ImageProvider?, AttachmentKey>((ref, a) async {
  final image = a.type.startsWith('image/');
  if (a.size > _previewLimit || !(image || a.type == 'application/pdf')) return null;
  final file = await ref.watch(attachmentFileProvider(a.id).future);
  if (image) return FileImage(file);
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
  return FileImage(page);
});
