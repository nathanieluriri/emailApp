import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../constants/gooey_fab.dart' hide kPillRadius;
import '../theme/colors.dart';
import '../theme/feedback.dart';
import '../theme/metrics.dart';
import '../theme/typography.dart';
import 'press_fade.dart';

const kOverflowPillGap = 62.0;

const kOverflowPillFirst = 50.0;

const kOverflowDotsBlob = 20.0;

const kOverflowPillBlob = 46.0;

const kOverflowGooPad = 42.0;

class GooMenuItem {
  const GooMenuItem({required this.label, required this.icon, this.destructive = false});

  final String label;
  final IconData icon;

  final bool destructive;
}

class GooMenu extends StatelessWidget {
  const GooMenu({super.key, required this.drives, required this.items, required this.onPick, required this.anchor, required this.bounds});

  final List<double> drives;

  final List<GooMenuItem> items;

  final ValueChanged<int> onPick;

  final Rect anchor;

  final Rect bounds;

  double get _run => kOverflowPillFirst + (items.length - 1) * kOverflowPillGap;

  bool get _upward => anchor.center.dy + _run + kPillHeight / 2 > bounds.bottom && anchor.center.dy - _run - kPillHeight / 2 >= bounds.top;

  @override
  Widget build(BuildContext context) {
    final sign = _upward ? -1.0 : 1.0;
    final height = _run + kPillHeight / 2;
    final spineX = kSortMenuWidth - kPillHeight / 2;
    final along = <double>[for (var i = 0; i < items.length; i++) drives[i] * (kOverflowPillFirst + i * kOverflowPillGap)];
    final originY = _upward ? height : 0.0;
    return Positioned(
      left: anchor.center.dx + kPillHeight / 2 - kSortMenuWidth,
      top: _upward ? anchor.center.dy - height : anchor.center.dy,
      width: kSortMenuWidth,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -kOverflowGooPad,
            right: -kOverflowGooPad,
            top: -kOverflowGooPad,
            bottom: -kOverflowGooPad,
            child: IgnorePointer(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(kGooAlphaThresholdMatrix),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: kGooBlurSigma, sigmaY: kGooBlurSigma, tileMode: TileMode.decal),
                  child: CustomPaint(
                    painter: _PillGooPainter(
                      origin: Offset(spineX + kOverflowGooPad, originY + kOverflowGooPad),
                      centresY: <double>[for (final a in along) originY + sign * a + kOverflowGooPad],
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (var i = items.length - 1; i >= 0; i--)
            Positioned(
              right: 0,
              top: originY + sign * along[i] - kPillHeight / 2,
              child: Opacity(
                opacity: interpolateClamped(drives[i], kActionOpacityInput, kActionOpacityOutput),
                child: Transform.scale(
                  scale: interpolateClamped(drives[i], kActionScaleInput, kActionScaleOutput),
                  alignment: Alignment.centerRight,
                  child: _Pill(item: items[i], onTap: () => onPick(i)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.item, required this.onTap});

  final GooMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destructive = item.destructive;
    return PaperPress(
      onTap: onTap,
      semanticLabel: item.label,
      feel: destructive ? Feel.commit : Feel.tap,
      child: SizedBox(
        height: kPillHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: destructive ? AppColors.accent : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(kPillRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPillPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: kPillGlyphSize, color: destructive ? AppColors.onAccent : AppColors.ink),
                const SizedBox(width: kPillGap),
                Text(item.label, style: AppText.actionPill.copyWith(color: destructive ? AppColors.onAccent : AppColors.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillGooPainter extends CustomPainter {
  const _PillGooPainter({required this.origin, required this.centresY});

  final Offset origin;

  final List<double> centresY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.surfaceHigh;
    canvas.drawCircle(origin, kOverflowDotsBlob, paint);
    for (final centreY in centresY) {
      _neck(canvas, paint, centreY);
      canvas.drawCircle(Offset(origin.dx, centreY), kOverflowPillBlob / 2, paint);
    }
  }

  void _neck(Canvas canvas, Paint paint, double centreY) {
    final travelled = (centreY - origin.dy).abs();
    if (travelled <= 0 || travelled >= kGooNeckBreak) return;
    final left = 1 - travelled / kGooNeckBreak;
    for (var i = 1; i <= kGooNeckCircles; i++) {
      final along = i / (kGooNeckCircles + 1);
      final waist = 1 - (1 - kGooNeckWaist) * math.sin(along * math.pi);
      final radius = ui.lerpDouble(kOverflowDotsBlob, kOverflowPillBlob / 2, along)! * waist * left;
      if (radius <= 0) continue;
      canvas.drawCircle(Offset(origin.dx, ui.lerpDouble(origin.dy, centreY, along)!), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PillGooPainter oldDelegate) {
    if (oldDelegate.origin != origin) return true;
    if (oldDelegate.centresY.length != centresY.length) return true;
    for (var i = 0; i < centresY.length; i++) {
      if (oldDelegate.centresY[i] != centresY[i]) return true;
    }
    return false;
  }
}
