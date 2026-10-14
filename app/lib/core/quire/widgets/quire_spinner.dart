import 'package:flutter/widgets.dart';

import '../painting/spinner_painter.dart';
import '../theme/colors.dart';

const String kSpinnerLabel = 'Opening';

class QuireSpinner extends StatefulWidget {
  const QuireSpinner({super.key, this.size = kSpinnerSize, this.color});

  final double size;

  final Color? color;

  @override
  State<QuireSpinner> createState() => _QuireSpinnerState();
}

class _QuireSpinnerState extends State<QuireSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: kSpinnerPeriod)..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: kSpinnerLabel,
      liveRegion: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _turn,
            builder: (context, _) => CustomPaint(
              painter: SpinnerPainter(turns: _turn.value, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

class QuireLoading extends StatelessWidget {
  const QuireLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.ground,
        child: const Center(child: QuireSpinner()),
      ),
    );
  }
}
