import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../core/brand.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/springs.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/widgets.dart';
import 'push_service.dart';

/// A banner that drops in from the top on Quire's drawer spring when mail arrives while the app is open.
void showMailBanner(BuildContext context, PushEvent event, {VoidCallback? onTap}) {
  Feel.turn.ring();
  if (!event.quiet) PushService.chime();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Banner(event: event, onTap: onTap, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Banner extends StatefulWidget {
  const _Banner({required this.event, this.onTap, required this.onDone});
  final PushEvent event;
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
    Future.delayed(const Duration(seconds: 5), _leave);
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
  Widget build(BuildContext context) {
    final e = widget.event;
    final sender = e.sender ?? 'New mail';
    return Positioned(
      left: 10,
      right: 10,
      top: MediaQuery.paddingOf(context).top + 8,
      child: AnimatedBuilder(
        animation: _drop,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -140 * (1 - _drop.value)),
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
              washRadius: 22,
              semanticLabel: 'New mail from $sender',
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 16, 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DefaultTextStyle(
                      style: AppText.docMeta.copyWith(color: AppColors.inkFaint),
                      maxLines: 1,
                      child: Row(
                        children: [
                          const BrandMark(size: 16),
                          const SizedBox(width: 6),
                          const Text('$kAppName \u00b7 '),
                          if (e.account != null) ...[
                            Flexible(child: Text(e.account!, overflow: TextOverflow.ellipsis)),
                            const Text(' \u00b7 '),
                          ],
                          const Text('now'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Avatar(name: sender, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sender,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.title.copyWith(color: AppColors.ink, fontSize: 16),
                              ),
                              if ((e.subject ?? '').isNotEmpty)
                                Text(
                                  e.subject!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodyTight.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
                                ),
                              if ((e.snippet ?? '').isNotEmpty)
                                Text(
                                  e.snippet!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodyTight.copyWith(color: AppColors.inkSoft),
                                ),
                            ],
                          ),
                        ),
                      ],
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
}
