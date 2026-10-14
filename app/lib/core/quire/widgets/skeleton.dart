import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/metrics.dart';

const kSkeletonFade = Duration(milliseconds: 260);

const double kSkeletonBar = 12.0;
const double kSkeletonBarSmall = 9.0;
const double kSkeletonRadius = 6.0;

class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: kListRowHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: kListRowPaddingX),
      child: Row(
        children: <Widget>[
          const _Block(width: kTypeMarkSize, height: kTypeMarkSize, radius: kTypeMarkRadius),
          const SizedBox(width: kListMarkGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _Block(width: 168, height: kSkeletonBar),
                SizedBox(height: kListTitleGap + 3),
                _Block(width: 104, height: kSkeletonBarSmall, faint: true),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(kGridCardRadius)),
    padding: const EdgeInsets.all(kGridCardPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Block(width: kTypeMarkGridSize + 20, height: kTypeMarkGridSize),
        const SizedBox(height: kGridCardPadding),
        const Expanded(child: _Block(width: double.infinity, height: null)),
        const SizedBox(height: kGridCardPadding),
        const _Block(width: 120, height: kSkeletonBar),
        const SizedBox(height: 8),
        const _Block(width: 76, height: kSkeletonBarSmall, faint: true),
      ],
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({required this.width, required this.height, this.radius, this.faint = false});

  final double width;
  final double? height;
  final double? radius;

  final bool faint;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: faint ? AppColors.surface : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(radius ?? kSkeletonRadius),
    ),
  );
}

class Skeletal extends StatelessWidget {
  const Skeletal({super.key, required this.quiet, required this.skeleton, required this.child});

  final double quiet;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = quiet.clamp(0.0, 1.0);
    if (t <= 0) return child;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Opacity(opacity: t, child: skeleton),
        ),
        Opacity(opacity: 1 - t, child: child),
      ],
    );
  }
}
