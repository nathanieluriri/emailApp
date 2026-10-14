import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/accounts_controller.dart';
import '../core/providers.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/easings.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/typography.dart';
import '../core/widgets.dart';
import 'push_service.dart';
import 'push_status.dart';

/// Offers to turn push on while it is off, and comes back three days after "Not now". Shows [fallback] otherwise.
class PushCard extends ConsumerStatefulWidget {
  const PushCard({super.key, required this.fallback});
  final Widget fallback;

  static const snoozeKey = 'push_card_snoozed_until';

  @override
  ConsumerState<PushCard> createState() => _PushCardState();
}

class _PushCardState extends ConsumerState<PushCard> with SingleTickerProviderStateMixin {
  late final _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late bool _snoozed = (ref.read(prefsProvider).getInt(PushCard.snoozeKey) ?? 0) > DateTime.now().millisecondsSinceEpoch;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ring.forward();
    });
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  Future<void> _turnOn() async {
    setState(() => _busy = true);
    final on = await PushService.enable();
    final accounts = ref.read(accountsProvider).value;
    if (on && accounts != null) await PushService.register(accounts.accounts);
    if (!mounted) return;
    setState(() => _busy = false);
    if (on) {
      Feel.commit.ring();
      showToast(context, 'You will hear about new mail right away');
    }
  }

  void _later() {
    Feel.tap.ring();
    ref.read(prefsProvider).setInt(PushCard.snoozeKey, DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch);
    setState(() => _snoozed = true);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pushStatusProvider);
    final paused = status.permission && !status.optedIn;
    final show = !_snoozed && !(status.permission && status.optedIn);
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: easeOutCubic,
      alignment: Alignment.topCenter,
      child: !show
          ? widget.fallback
          : Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _ring,
                        builder: (_, child) {
                          final t = _ring.value;
                          return Transform.rotate(
                            angle: math.sin(t * math.pi * 6) * (1 - t) * 0.45,
                            alignment: Alignment.topCenter,
                            child: child,
                          );
                        },
                        child: Icon(paused ? LucideIcons.bellOff : LucideIcons.bellRing, size: 22, color: AppColors.accentBright),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paused ? 'Notifications are paused' : 'Turn on notifications',
                              style: AppText.title.copyWith(color: AppColors.ink, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              paused
                                  ? 'This phone is not getting new mail alerts. Turn them back on any time.'
                                  : 'Know the moment new mail lands, with who sent it and a preview.',
                              style: AppText.bodyTight.copyWith(color: AppColors.inkSoft, fontSize: 15, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : _later,
                        child: Text('Not now', style: AppText.actionPill.copyWith(color: AppColors.inkSoft)),
                      ),
                      const SizedBox(width: 6),
                      PillButton(label: 'Turn on', busy: _busy, feel: Feel.turn, onTap: _turnOn),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
