import 'package:bridgewood_mail/core/brand.dart';
import 'package:bridgewood_mail/core/quire/theme/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The launcher icons are cut from this render: `flutter test test/brand --update-goldens`.
void main() {
  testWidgets('app mark', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: CustomPaint(
            size: const Size.square(1024),
            painter: MarkPainter(ink: const Color(0xFF1C1B1F), accent: AppColors.light.accent),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('mark.png'));
  });
}
