import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('quirepost/files');

/// The formats Quire reads, by its own names for them, against the extensions it knows them by.
const _formats = {
  'pdf': 'pdf',
  'docx': 'docx',
  'xlsx': 'xlsx',
  'pptx': 'pptx',
  'csv': 'csv',
  'tsv': 'csv',
  'md': 'md',
  'markdown': 'md',
  'txt': 'md',
};

/// The types Quire registers to open, which an explicit intent has to match.
const _types = {
  'pdf': 'application/pdf',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'csv': 'text/csv',
  'tsv': 'text/tab-separated-values',
  'md': 'text/markdown',
  'markdown': 'text/markdown',
  'txt': 'text/plain',
};

String _extension(String name) => name.contains('.') ? name.split('.').last.toLowerCase() : '';

/// What Quire would read [name] as ('pdf', 'docx', 'xlsx', 'pptx', 'csv' or 'md'), or null for anything else.
String? quireFormat(String name, String type) =>
    _formats[_extension(name)] ?? _types.entries.where((e) => e.value == type.toLowerCase()).map((e) => _formats[e.key]).firstOrNull;

/// Whether Quire is on this phone, asked once a session.
final quireInstalledProvider = FutureProvider<bool>((ref) async {
  try {
    return await _channel.invokeMethod<bool>('quireInstalled') ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
});

/// Hands a file to Quire under its own name, which Quire takes as the document's title. False if Quire would not
/// take it.
Future<bool> openInQuire(Uint8List bytes, {required String id, required String name, required String type}) async {
  final format = quireFormat(name, type);
  if (format == null) return false;
  final ext = _extension(name);
  final dir = Directory('${(await getTemporaryDirectory()).path}/quire/$id');
  await dir.create(recursive: true);
  final file = File('${dir.path}/${name.replaceAll(RegExp(r'[/\\]'), '_')}');
  await file.writeAsBytes(bytes, flush: true);
  try {
    return await _channel.invokeMethod<bool>('openInQuire', {'path': file.path, 'type': _types[ext] ?? _types[format]!}) ?? false;
  } on PlatformException {
    return false;
  }
}
