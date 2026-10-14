import 'package:flutter/widgets.dart';

import '../../constants/gooey_fab.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../press_fade.dart';

class FabActionPill extends StatelessWidget {
  const FabActionPill({super.key, required this.action, required this.drive, required this.interactive, required this.onPressed});

  final FabAction action;
  final Animation<double> drive;

  final bool interactive;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: drive,
      builder: (context, child) {
        final value = drive.value;
        final scale = interpolateClamped(value, kActionScaleInput, kActionScaleOutput);
        return Positioned(
          right: kFabCanvasWidth - kFabCenterX - kPillRadius * scale,
          top: kFabCenterY + value * action.offsetY - kPillHeight / 2,
          child: IgnorePointer(
            ignoring: !interactive,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.centerRight,
              child: Opacity(opacity: interpolateClamped(value, kActionOpacityInput, kActionOpacityOutput), child: child),
            ),
          ),
        );
      },
      child: PaperPress(
        onTap: onPressed,
        semanticLabel: action.label,
        child: SizedBox(
          height: kPillHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(kPillRadius)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPillPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.glyph, size: kPillGlyphSize, color: AppColors.onAccent),
                  const SizedBox(width: kPillGap),
                  Text(action.label, style: AppText.actionPill.copyWith(color: AppColors.onAccent)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
