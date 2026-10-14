import 'package:flutter/material.dart';

import 'quire/theme/colors.dart';
import 'quire/theme/feedback.dart';
import 'quire/widgets/goo_menu.dart';
import 'quire/widgets/gooey_fab/gooey_fab_controller.dart';

export 'quire/widgets/goo_menu.dart' show GooMenuItem;

/// Quire's overflow: pills peel off the button that was pressed on threads of goo.
/// Completes with the picked index, or null when dismissed.
Future<int?> showGooMenu(BuildContext anchor, List<GooMenuItem> items) {
  final box = anchor.findRenderObject()! as RenderBox;
  final width = MediaQuery.sizeOf(anchor).width;
  final at = box.localToGlobal(Offset.zero) & box.size;
  final rect = at.shift(Offset(-(at.center.dx + 34 - width).clamp(0.0, double.infinity), 0));
  return Navigator.of(anchor).push<int>(
    PageRouteBuilder<int>(
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => _GooMenuLayer(anchor: rect, items: items),
    ),
  );
}

class _GooMenuLayer extends StatefulWidget {
  const _GooMenuLayer({required this.anchor, required this.items});
  final Rect anchor;
  final List<GooMenuItem> items;

  @override
  State<_GooMenuLayer> createState() => _GooMenuLayerState();
}

class _GooMenuLayerState extends State<_GooMenuLayer> with TickerProviderStateMixin {
  late final _goo = GooeyFabController(vsync: this, actionCount: widget.items.length);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goo.toggle());
  }

  @override
  void dispose() {
    _goo.dispose();
    super.dispose();
  }

  Future<void> _close([int? picked]) async {
    if (_closing) return;
    _closing = true;
    if (picked == null) Feel.tap.ring();
    if (_goo.isOpen) _goo.toggle();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (mounted) Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: AnimatedBuilder(
                animation: _goo.scrim,
                builder: (context, _) => ColoredBox(color: AppColors.scrim.withValues(alpha: AppColors.scrim.a * 0.6 * _goo.scrim.value)),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _goo.animations,
            builder: (context, _) => Stack(
              children: [
                GooMenu(
                  drives: [for (var i = 0; i < widget.items.length; i++) _goo.actionDrive(i).value],
                  items: widget.items,
                  anchor: widget.anchor,
                  bounds: Rect.fromLTRB(0, padding.top, size.width, size.height - padding.bottom),
                  onPick: _close,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
