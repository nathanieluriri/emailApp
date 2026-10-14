import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/springs.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';

/// A banner that drops in from the top on Quire's drawer spring when mail arrives while the app is open.
void showMailBanner(BuildContext context, {required String title, required String body, VoidCallback? onTap}) {
  Feel.turn.ring();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Banner(title: title, body: body, onTap: onTap, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Banner extends StatefulWidget {
  const _Banner({required this.title, required this.body, this.onTap, required this.onDone});
  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback onDone;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final _drop = AnimationController.unbounded(vsync: this)..animateWith(SpringSimulation(AppSprings.drawer, 0, 1, 0));
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), _leave);
  }

  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    await _drop.animateWith(SpringSimulation(AppSprings.drawer, _drop.value, 0, 0));
    widget.onDone();
  }

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 12,
    right: 12,
    top: MediaQuery.paddingOf(context).top + 8,
    child: AnimatedBuilder(
      animation: _drop,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -120 * (1 - _drop.value)),
        child: Opacity(opacity: _drop.value.clamp(0.0, 1.0), child: child),
      ),
      child: GestureDetector(
        onVerticalDragEnd: (d) => (d.primaryVelocity ?? 0) < 0 ? _leave() : null,
        child: Material(
          type: MaterialType.transparency,
          child: PaperPress(
            onTap: () {
              widget.onTap?.call();
              _leave();
            },
            washRadius: 18,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    child: Icon(LucideIcons.mail, size: 18, color: AppColors.onAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title.copyWith(color: AppColors.ink),
                        ),
                        Text(
                          widget.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyTight.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
