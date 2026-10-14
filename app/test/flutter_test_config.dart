import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loaders = <String, FontLoader>{};
  for (final file in Directory('assets/fonts').listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    final family = file.uri.pathSegments.last.split('-').first;
    loaders.putIfAbsent(family, () => FontLoader(family)).addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  loaders['packages/lucide_icons_flutter/Lucide'] = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
  for (final loader in loaders.values) {
    await loader.load();
  }
  await testMain();
}
