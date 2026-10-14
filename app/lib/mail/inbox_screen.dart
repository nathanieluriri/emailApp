import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../accounts/account_switcher.dart';
import '../accounts/accounts_controller.dart';
import '../compose/compose_args.dart';
import '../core/motion.dart';
import '../core/providers.dart';
import '../core/quire/painting/hamburger_painter.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/easings.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/metrics.dart';
import '../core/quire/theme/springs.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/gooey_fab/gooey_fab.dart';
import '../core/quire/widgets/press_fade.dart';
import '../core/quire/widgets/pull_to_refresh.dart';
import '../core/quire/widgets/skeleton.dart';
import '../core/widgets.dart';
import '../notifications/in_app_banner.dart';
import '../notifications/push_card.dart';
import '../notifications/push_service.dart';
import '../templates/template.dart';
import 'label_picker.dart';
import 'mail_providers.dart';
import 'mail_repository.dart';
import 'mail_row.dart';
import 'models.dart';
import 'nav_drawer.dart';

const _bar = 56.0;

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> with SingleTickerProviderStateMixin {
  static const _flingVelocity = 300.0;
  late final _drawer = AnimationController(vsync: this);
  final _scroll = ScrollController();
  final _fabShown = ValueNotifier(true);
  final _selected = <String>{};
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
        showMailBanner(context, e, onTap: () => PushService.open(e));
      }
    });
  }

  @override
  void dispose() {
    _pushes?.cancel();
    _drawer.dispose();
    _scroll.dispose();
    _fabShown.dispose();
    super.dispose();
  }

  void _onScroll() {
    final dir = _scroll.position.userScrollDirection;
    if (dir == ScrollDirection.reverse) _fabShown.value = false;
    if (dir == ScrollDirection.forward || _scroll.offset < 40) _fabShown.value = true;
    if (_scroll.position.extentAfter < 600) ref.read(inboxProvider(ref.read(currentLabelProvider)).notifier).loadMore();
  }

  // A spring only gets within tolerance of its target; snap so a closed drawer leaves no invisible scrim catching taps.
  void _settleDrawer(bool open, [double velocity = 0]) =>
      _drawer.animateWith(SpringSimulation(AppSprings.drawer, _drawer.value, open ? 1 : 0, velocity)).then((_) {
        if (mounted) _drawer.value = open ? 1 : 0;
      });

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
    setState(_selected.clear);
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

  void _toggleSelect(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _bulk(String done, Future<void> Function(Message m) action) async {
    final label = ref.read(currentLabelProvider);
    final messages = ref.read(inboxProvider(label)).value?.messages.where((m) => _selected.contains(m.id)).toList() ?? [];
    Feel.commit.ring();
    setState(_selected.clear);
    try {
      await Future.wait(messages.map(action));
      await ref.read(inboxProvider(label).notifier).refresh();
      ref.invalidate(labelsProvider);
      if (mounted) showToast(context, done);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  Future<void> _archive(Message m, String label) async {
    final inbox = ref.read(inboxProvider(label).notifier);
    try {
      await inbox.archive(m);
      if (mounted) showToast(context, 'Archived', action: 'Undo', onAction: () => inbox.unarchive(m));
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

  Future<void> _fabAction(int i) async {
    switch (i) {
      case 0:
        context.push('/compose');
      case 1:
        final t = await context.push<MailTemplate>('/templates?pick=1');
        if (t != null && mounted) context.push('/compose', extra: ComposeArgs(template: t));
      case 2:
        context.push('/compose', extra: const ComposeArgs(design: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = ref.watch(currentLabelProvider);
    final labels = ref.watch(labelsProvider).value ?? [];
    final title = systemLabels[label] ?? labels.where((l) => l.id == label).firstOrNull?.name ?? 'Mail';
    final width = _drawerWidth;
    final top = MediaQuery.paddingOf(context).top;
    final api = ref.read(mailRepositoryProvider).api;
    final selecting = _selected.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
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
                    SizedBox(
                      height: _bar + 16,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, -0.2), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        ),
                        child: selecting
                            ? _SelectionBar(
                                key: const ValueKey('selection'),
                                count: _selected.length,
                                onClose: () => setState(_selected.clear),
                                onArchive: () => _bulk('Archived', (m) => api.updateThread(m.threadId, archived: true)),
                                onDelete: () =>
                                    _bulk('Moved to Trash', (m) => api.updateThread(m.threadId, add: ['trash'], remove: ['inbox'])),
                                onRead: () => _bulk('Marked as read', (m) => api.updateThread(m.threadId, read: true)),
                              )
                            : const _SearchBar(key: ValueKey('search')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
                            selected: _selected,
                            onSelect: _toggleSelect,
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
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: _fabShown,
                builder: (context, shown, child) => AnimatedSlide(
                  offset: shown && !selecting ? Offset.zero : const Offset(0, 0.3),
                  duration: const Duration(milliseconds: 260),
                  curve: easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !shown || selecting,
                    child: AnimatedOpacity(opacity: shown && !selecting ? 1 : 0, duration: const Duration(milliseconds: 200), child: child),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                  child: GooeyFab(onSelected: _fabAction),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _drawer,
              builder: (context, _) {
                final p = _drawer.value.clamp(0.0, 1.0);
                if (p < 0.01) return const SizedBox.shrink();
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
            if (!selecting)
              Positioned(
                left: 8,
                top: top + 8 + (_bar - kBurgerTarget - 8) / 2,
                child: PaperPress(
                  onTap: _toggleDrawer,
                  feel: Feel.none,
                  semanticLabel: 'Menu',
                  washRadius: 24,
                  child: SizedBox.square(
                    dimension: kBurgerTarget + 8,
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
      ),
    );
  }
}

/// Gmail's header: menu, a centred search pill, and your account picture.
class _SearchBar extends ConsumerWidget {
  const _SearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: PaperPress(
              onTap: () => context.push('/search'),
              semanticLabel: 'Search in emails',
              washRadius: _bar / 2,
              child: Hero(
                tag: 'search',
                child: Material(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(_bar / 2),
                  child: SizedBox(
                    height: _bar,
                    child: Center(
                      child: Text('Search in emails', style: AppText.search.copyWith(color: AppColors.inkSoft, fontSize: 16)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          PaperPress(
            onTap: () => showAccountSwitcher(context),
            semanticLabel: 'Switch account',
            washRadius: 24,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, a) => RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(a),
                  child: ScaleTransition(scale: a, child: child),
                ),
                child: Avatar(key: ValueKey(account?.id), name: account?.name ?? '?', size: 38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.onArchive,
    required this.onDelete,
    required this.onRead,
  });
  final int count;
  final VoidCallback onClose;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    child: Container(
      height: _bar,
      decoration: BoxDecoration(color: AppColors.accentMuted, borderRadius: BorderRadius.circular(_bar / 2)),
      child: Row(
        children: [
          IconPress(icon: LucideIcons.x, label: 'Clear selection', onTap: onClose),
          const SizedBox(width: 4),
          Text('$count', style: AppText.title.copyWith(color: AppColors.ink)),
          const Spacer(),
          IconPress(icon: LucideIcons.archive, label: 'Archive', onTap: onArchive),
          IconPress(icon: LucideIcons.trash2, label: 'Delete', onTap: onDelete),
          IconPress(icon: LucideIcons.mailOpen, label: 'Mark as read', onTap: onRead),
          const SizedBox(width: 4),
        ],
      ),
    ),
  );
}

/// Gmail's one-time hint, dismissed for good.
class _Tip extends ConsumerStatefulWidget {
  const _Tip();

  @override
  ConsumerState<_Tip> createState() => _TipState();
}

class _TipState extends ConsumerState<_Tip> {
  static const _key = 'tip_select_dismissed';
  late bool _shown = !(ref.read(prefsProvider).getBool(_key) ?? false);

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 260),
    curve: easeOutCubic,
    child: !_shown
        ? const SizedBox(width: double.infinity)
        : Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(LucideIcons.pointer, size: 22, color: AppColors.accentBright),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Tap a sender image to select that conversation.',
                    style: AppText.bodyTight.copyWith(color: AppColors.inkSoft, fontSize: 15, height: 1.35),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Feel.tap.ring();
                    ref.read(prefsProvider).setBool(_key, true);
                    setState(() => _shown = false);
                  },
                  child: Text('Dismiss', style: AppText.actionPill.copyWith(color: AppColors.accentBright)),
                ),
              ],
            ),
          ),
  );
}

class _MailList extends ConsumerWidget {
  const _MailList({
    required this.label,
    required this.scroll,
    required this.selected,
    required this.onSelect,
    required this.onArchive,
    required this.onStar,
  });
  final String label;
  final ScrollController scroll;
  final Set<String> selected;
  final ValueChanged<String> onSelect;
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
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: state.messages.length + 1 + (state.nextCursor != null ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == 0) return const PushCard(fallback: _Tip());
                  final index = i - 1;
                  if (index == state.messages.length) return const Padding(padding: EdgeInsets.all(16), child: Loader());
                  final m = state.messages[index];
                  final selecting = selected.isNotEmpty;
                  return EntryMotion(
                    key: ValueKey(m.id),
                    index: index,
                    child: MailRow(
                      message: m,
                      showRecipient: label == 'sent',
                      selected: selected.contains(m.id),
                      onSelect: () => onSelect(m.id),
                      onTap: () => selecting ? onSelect(m.id) : context.push('/thread/${m.threadId}?hero=${m.id}'),
                      onStar: () => onStar(m),
                      onArchive: label == 'inbox' && !selecting ? () => onArchive(m) : null,
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
