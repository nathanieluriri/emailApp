import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../constants/gooey_fab.dart' show kGooAlphaThresholdMatrix;
import '../painting/wash_painter.dart';
import '../theme/colors.dart';
import '../theme/easings.dart';
import '../theme/feedback.dart';
import '../theme/metrics.dart';

const kPressScale = 0.985;

const kPressRelease = Duration(milliseconds: 120);

class PaperPress extends StatefulWidget {
  const PaperPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
    this.feel = Feel.tap,
    this.holdFeel = Feel.turn,
    this.wash = true,
    this.washRadius = kWashRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final bool enabled;

  final String? semanticLabel;

  final Feel feel;

  final Feel holdFeel;

  final bool wash;

  final double washRadius;

  @override
  State<PaperPress> createState() => _PaperPressState();
}

class _PaperPressState extends State<PaperPress> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(vsync: this, duration: kPress, reverseDuration: kPressRelease);

  late final AnimationController _well = AnimationController(vsync: this, duration: kWashRise, reverseDuration: kWashSink);

  late final AnimationController _flood = AnimationController(vsync: this, duration: kWashFlood);

  Offset? _point;

  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _flood.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _well.value = 0;
        _flood.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _press.dispose();
    _well.dispose();
    _flood.dispose();
    super.dispose();
  }

  void _down(Offset at) {
    if (!widget.enabled) return;
    _point = at;
    _pressing = true;
    _press.forward();
    if (widget.wash) {
      _flood.value = 0;
      _well.forward();
    }
  }

  void _up() {
    _press.reverse();
    if (widget.wash && _pressing) _flood.forward(from: 0);
    _pressing = false;
  }

  void _cancel() {
    _press.reverse();
    _well.reverse();
    _pressing = false;
  }

  void _tap() {
    widget.feel.ring();
    widget.onTap!();
  }

  void _hold() {
    widget.holdFeel.ring();
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _down(details.localPosition),
        onTapUp: (_) => _up(),
        onTapCancel: _cancel,
        onTap: widget.enabled && widget.onTap != null ? _tap : null,
        onLongPress: widget.enabled && widget.onLongPress != null ? _hold : null,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final t = easeOutQuad.transform(_press.value);
            return Transform.scale(scale: 1 - (1 - kPressScale) * t, child: child);
          },
          child: _washed(widget.child),
        ),
      ),
    );
  }

  Widget _washed(Widget child) {
    if (!widget.wash) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_well, _flood]),
              builder: (context, _) {
                final well = easeOutCubic.transform(_well.value);
                final flood = easeOutCubic.transform(_flood.value);
                final at = _point;
                if ((well <= 0 && flood <= 0) || at == null) {
                  return const SizedBox.shrink();
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(widget.washRadius),
                  child: Opacity(
                    opacity: kWashOpacity * (1 - flood),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(kGooAlphaThresholdMatrix),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: kWashBlurSigma, sigmaY: kWashBlurSigma),
                        child: CustomPaint(
                          painter: WashPainter(at: at, well: well, flood: flood, colour: AppColors.accentBright),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
