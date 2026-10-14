import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/account_switcher.dart';
import '../accounts/accounts_controller.dart';
import '../core/motion.dart';
import '../core/quire/painting/hamburger_painter.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/metrics.dart';
import '../core/quire/theme/springs.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/quire/widgets/pull_to_refresh.dart';
import '../core/quire/widgets/skeleton.dart';
import '../core/widgets.dart';
import '../notifications/in_app_banner.dart';
import '../notifications/push_service.dart';
import 'label_picker.dart';
import 'mail_providers.dart';
import 'mail_row.dart';
import 'models.dart';
import 'nav_drawer.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> with SingleTickerProviderStateMixin {
  static const _flingVelocity = 300.0;
  late final _drawer = AnimationController(vsync: this);
  final _scroll = ScrollController();
  final _fabExtended = ValueNotifier(true);
  StreamSubscription<PushEvent>? _pushes;

  double get _drawerWidth => drawerWidth(MediaQuery.sizeOf(context).width);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _pushes = PushService.events.stream.where((e) => !e.opened).listen((e) {
      ref.invalidate(inboxProvider);
      ref.invalidate(labelsProvider);
      if (mounted) {
        showMailBanner(
          context,
          title: e.title ?? 'New mail',
          body: e.body ?? '',
          onTap: e.threadId == null ? null : () => context.push('/thread/${e.threadId}'),
        );
      }
    });
  }

  @override
  void dispose() {
    _pushes?.cancel();
    _drawer.dispose();
    _scroll.dispose();
    _fabExtended.dispose();
    super.dispose();
  }

  void _onScroll() {
    final dir = _scroll.position.userScrollDirection;
    if (dir == ScrollDirection.reverse) _fabExtended.value = false;
    if (dir == ScrollDirection.forward || _scroll.offset < 40) _fabExtended.value = true;
    if (_scroll.position.extentAfter < 600) ref.read(inboxProvider(ref.read(currentLabelProvider)).notifier).loadMore();
  }

  void _settleDrawer(bool open, [double velocity = 0]) =>
      _drawer.animateWith(SpringSimulation(AppSprings.drawer, _drawer.value, open ? 1 : 0, velocity));

  void _toggleDrawer() {
    Feel.turn.ring();
    _settleDrawer(_drawer.value < 0.5);
  }

  void _dragDrawer(double delta) => _drawer
    ..stop()
    ..value = (_drawer.value + delta / _drawerWidth).clamp(0.0, 1.0);

  void _endDrawerDrag(double velocity) {
    Feel.turn.ring();
    _settleDrawer(velocity.abs() > _flingVelocity ? velocity > 0 : _drawer.value > 0.5, velocity / _drawerWidth);
  }

  void _select(String label) {
    ref.read(currentLabelProvider.notifier).select(label);
    _settleDrawer(false);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _link(String path) {
    _settleDrawer(false);
    if (path == '/labels') {
      showQuireSheet(context, (_) => const LabelsManager());
    } else {
      context.push(path);
    }
  }

  Future<void> _archive(Message m, String label) async {
    final inbox = ref.read(inboxProvider(label).notifier);
    try {
      await inbox.archive(m);
      if (mounted) showToast(context, 'Archived', action: 'Undo', onAction: () => inbox.restore(m));
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  Future<void> _star(Message m, String label) async {
    try {
      await ref.read(inboxProvider(label).notifier).toggleStar(m);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = ref.watch(currentLabelProvider);
    final labels = ref.watch(labelsProvider).value ?? [];
    final title = systemLabels[label] ?? labels.where((l) => l.id == label).firstOrNull?.name ?? 'Mail';
    final width = _drawerWidth;
    return Scaffold(
      floatingActionButton: _ComposeFab(extended: _fabExtended),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (d) => d.globalPosition.dx < 28 || _drawer.value > 0 ? _dragDrawer(d.delta.dx) : null,
            onHorizontalDragEnd: (d) => _drawer.value > 0 ? _endDrawerDrag(d.primaryVelocity ?? 0) : null,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(onMenu: _toggleDrawer),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: kDim,
                        child: Text(
                          title,
                          key: ValueKey(title),
                          style: AppText.sortLabel.copyWith(color: AppColors.inkSoft),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: kDeskWakingFade,
                      child: KeyedSubtree(
                        key: ValueKey('$label-${ref.watch(activeAccountProvider)?.id}'),
                        child: _MailList(
                          label: label,
                          scroll: _scroll,
                          onArchive: (m) => _archive(m, label),
                          onStar: (m) => _star(m, label),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _drawer,
            builder: (context, _) {
              final p = _drawer.value.clamp(0.0, 1.0);
              if (p == 0) return const SizedBox.shrink();
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      Feel.tap.ring();
                      _settleDrawer(false);
                    },
                    onHorizontalDragUpdate: (d) => _dragDrawer(d.delta.dx),
                    onHorizontalDragEnd: (d) => _endDrawerDrag(d.primaryVelocity ?? 0),
                    child: Container(color: AppColors.scrim.withValues(alpha: AppColors.scrim.a * p)),
                  ),
                  Positioned(
                    left: -width * (1 - _drawer.value),
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) => _dragDrawer(d.delta.dx),
                      onHorizontalDragEnd: (d) => _endDrawerDrag(d.primaryVelocity ?? 0),
                      child: NavDrawer(selected: label, onSelect: _select, onLink: _link),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            left: kTopBarPaddingX,
            top: MediaQuery.paddingOf(context).top + 8,
            child: PaperPress(
              onTap: _toggleDrawer,
              feel: Feel.none,
              semanticLabel: 'Menu',
              washRadius: 20,
              child: SizedBox.square(
                dimension: kBurgerTarget,
                child: AnimatedBuilder(
                  animation: _drawer,
                  builder: (context, _) => CustomPaint(
                    painter: HamburgerPainter(progress: _drawer.value, color: AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kTopBarPaddingX, 8, kTopBarPaddingX, 0),
      child: Container(
        height: 52,
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(26)),
        child: Row(
          children: [
            const SizedBox(width: kBurgerTarget + 8),
            Expanded(
              child: PaperPress(
                onTap: () => context.push('/search'),
                semanticLabel: 'Search in emails',
                washRadius: 26,
                child: Hero(
                  tag: 'search',
                  child: Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      height: 52,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Search in emails', style: AppText.search.copyWith(color: AppColors.inkSoft)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PaperPress(
              onTap: () => showAccountSwitcher(context),
              semanticLabel: 'Switch account',
              washRadius: 22,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, a) => RotationTransition(
                    turns: Tween(begin: 0.75, end: 1.0).animate(a),
                    child: ScaleTransition(scale: a, child: child),
                  ),
                  child: Avatar(key: ValueKey(account?.id), name: account?.nickname ?? '?', size: 34),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailList extends ConsumerWidget {
  const _MailList({required this.label, required this.scroll, required this.onArchive, required this.onStar});
  final String label;
  final ScrollController scroll;
  final ValueChanged<Message> onArchive;
  final ValueChanged<Message> onStar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider(label));
    final controller = ref.read(inboxProvider(label).notifier);
    Future<void> refresh() async {
      try {
        await controller.refresh();
        ref.invalidate(labelsProvider);
      } catch (e) {
        if (context.mounted) showToast(context, 'Offline: showing saved mail');
      }
    }

    return switch (inbox) {
      AsyncValue(value: final state?) => PullToRefresh(
        onRefresh: refresh,
        child: state.messages.isEmpty
            ? LayoutBuilder(
                builder: (context, box) => ListView(
                  controller: scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: box.maxHeight,
                      child: EmptyState(
                        icon: label == 'inbox' ? null : LucideIcons.inbox,
                        title: label == 'inbox' ? 'All caught up' : 'Nothing here',
                        body: label == 'inbox'
                            ? 'New mail lands here the moment it arrives.'
                            : 'Mail you file here will show up in this list.',
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: state.messages.length + (state.nextCursor != null ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == state.messages.length) return const Padding(padding: EdgeInsets.all(16), child: Loader());
                  final m = state.messages[i];
                  return EntryMotion(
                    key: ValueKey(m.id),
                    index: i,
                    child: MailRow(
                      message: m,
                      onTap: () => context.push('/thread/${m.threadId}?hero=${m.id}'),
                      onStar: () => onStar(m),
                      onArchive: label == 'inbox' ? () => onArchive(m) : null,
                    ),
                  );
                },
              ),
      ),
      AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(inboxProvider(label))),
      _ => Skeletal(
        quiet: 0,
        skeleton: ListView(children: List.generate(8, (_) => const SkeletonRow())),
        child: const SizedBox.shrink(),
      ),
    };
  }
}

/// Gmail's compose button: a wide pill that folds to a square while you scroll down,
/// and flies open into the compose screen.
class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.extended});
  final ValueNotifier<bool> extended;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: extended,
    builder: (context, wide, _) => PaperPress(
      onTap: () => context.push('/compose'),
      semanticLabel: 'Compose',
      washRadius: 18,
      child: Hero(
        tag: 'compose',
        flightShuttleBuilder: composeFlight,
        child: Material(
          color: AppColors.accentMuted,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: 56,
            width: wide ? 138 : 56,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: 138,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const SizedBox(width: 18),
                    Icon(LucideIcons.pencil, color: AppColors.ink, size: 20),
                    const SizedBox(width: 14),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: wide ? 1 : 0,
                      child: Text('Compose', style: AppText.actionPill.copyWith(color: AppColors.ink)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget composeFlight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to,
) => AnimatedBuilder(
  animation: animation,
  builder: (context, _) => Material(
    color: Color.lerp(AppColors.accentMuted, AppColors.ground, animation.value),
    borderRadius: BorderRadius.circular(18 * (1 - animation.value)),
  ),
);
