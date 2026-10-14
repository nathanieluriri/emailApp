import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts/accounts_controller.dart';
import '../core/widgets.dart';

/// Picks an image and stores it on the worker, so it renders in every recipient's inbox.
Future<String?> pickAndUploadImage(BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.pickFiles(type: FileType.image);
  final file = picked.firstOrNull;
  if (file == null) return null;
  final ext = (file.extension ?? 'png').toLowerCase();
  try {
    return await ref.read(apiProvider).uploadImage(await file.readAsBytes(), 'image/${ext == 'jpg' ? 'jpeg' : ext}');
  } catch (e) {
    if (context.mounted) showToast(context, 'Upload failed: $e');
    return null;
  }
}
