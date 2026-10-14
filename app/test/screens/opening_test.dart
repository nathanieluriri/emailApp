import 'package:bridgewood_mail/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_test.dart';

void main() {
  testWidgets('opening animation frames', (tester) async {
    await tester.runAsync(() async {});
    final shots = [150, 450, 650, 900, 1250];
    var at = 0;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    await bootQuiet(tester);
    for (final ms in shots) {
      await tester.pump(Duration(milliseconds: ms - at));
      at = ms;
      await expectLater(find.byType(App), matchesGoldenFile('goldens/opening_$ms.png'));
    }
    await settle(tester);
  });
}
