import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../constants/gooey_fab.dart';
import '../../painting/goo_circles_painter.dart';
import '../../theme/colors.dart';
import '../../theme/feedback.dart';
import '../press_fade.dart';
import 'fab_action_pill.dart';
import 'gooey_fab_controller.dart';

class GooeyFab extends StatefulWidget {
  const GooeyFab({super.key, this.onSelected});

  final ValueChanged<int>? onSelected;

  @override
  State<GooeyFab> createState() => _GooeyFabState();
}

class _GooeyFabState extends State<GooeyFab> with TickerProviderStateMixin {
  late final GooeyFabController _controller = GooeyFabController(vsync: this);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onOpenChanged);
  }

  void _onOpenChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onOpenChanged);
    _controller.dispose();
    super.dispose();
  }

  void _toggle() => _controller.toggle();

  Future<void> _select(int index) async {
    _toggle();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) widget.onSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _controller.isOpen;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !isOpen,
            child: AnimatedBuilder(
              animation: _controller.scrim,
              builder: (context, child) => ColoredBox(
                color: AppColors.scrim.withValues(alpha: AppColors.scrim.a * _controller.scrim.value),
                child: child,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Feel.tap.ring();
                  _toggle();
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: kFabCanvasBottomOffset,
          width: kFabCanvasWidth,
          height: kFabCanvasHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(child: _GooLayer(controller: _controller)),
              ),
              for (var i = kFabActions.length - 1; i >= 0; i--)
                FabActionPill(action: kFabActions[i], drive: _controller.actionDrive(i), interactive: isOpen, onPressed: () => _select(i)),
              _FabButton(progress: _controller.progress, onTap: _toggle),
            ],
          ),
        ),
      ],
    );
  }
}

class _FabButton extends StatelessWidget {
  const _FabButton({required this.progress, required this.onTap});

  final Animation<double> progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final value = progress.value;
        final open = value.clamp(0.0, 1.0);
        final size = ui.lerpDouble(kFabRestSize, kFabOpenSize, open)!;
        return Positioned(
          left: kFabCenterX - size / 2,
          top: kFabCenterY - size / 2,
          width: size,
          height: size,
          child: PaperPress(
            onTap: onTap,
            semanticLabel: 'Actions',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(AppColors.accent, AppColors.accentBright, open),
                borderRadius: BorderRadius.circular(ui.lerpDouble(kFabRestRadius, kFabOpenRadius, open)!),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: value * kFabOpenRotationDegrees * math.pi / 180,
                  child: Icon(LucideIcons.plus, size: kFabGlyphSize, color: Color.lerp(AppColors.onAccent, AppColors.onAccentBright, open)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GooLayer extends StatelessWidget {
  const _GooLayer({required this.controller});

  final GooeyFabController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(kGooAlphaThresholdMatrix),
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: kGooBlurSigma, sigmaY: kGooBlurSigma, tileMode: TileMode.decal),
          child: AnimatedBuilder(
            animation: controller.animations,
            builder: (context, _) => CustomPaint(
              painter: GooCirclesPainter(
                actionCentresY: <double>[
                  for (var i = 0; i < kFabActions.length; i++) kFabCenterY + controller.actionDrive(i).value * kFabActions[i].offsetY,
                ],
                buttonDiameter: ui.lerpDouble(kGooButtonRestDiameter, kGooButtonOpenDiameter, controller.progress.value.clamp(0.0, 1.0))!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
