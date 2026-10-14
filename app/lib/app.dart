import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accounts/accounts_controller.dart';
import 'compose/compose_args.dart';
import 'core/brand.dart';
import 'core/opening.dart';
import 'core/providers.dart';
import 'core/quire/theme/colors.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'notifications/push_service.dart';
import 'notifications/reminders.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subs
      ..add(PushService.events.stream.where((e) => e.opened).listen(_openPush))
      ..add(Reminders.taps.stream.listen((host) => _openPush(PushEvent(host: host, opened: true))));
    final pending = PushService.pendingOpen ?? (Reminders.launchHost == null ? null : PushEvent(host: Reminders.launchHost, opened: true));
    PushService.pendingOpen = null;
    if (pending != null) ref.read(accountsProvider.future).then((_) => _openPush(pending));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = ref.read(accountsProvider).value?.active;
    if (state == AppLifecycleState.resumed && active != null) PushService.clearFor(active.email);
  }

  Future<void> _openPush(PushEvent e) async {
    await ref.read(accountsProvider.future);
    final controller = ref.read(accountsProvider.notifier);
    final target = e.host == null ? null : controller.forPush(e.host!, e.account);
    if (target != null) await controller.switchTo(target.id);
    final active = ref.read(accountsProvider).value?.active;
    if (active != null) PushService.clearFor(active.email);
    final router = ref.read(routerProvider);
    router.go('/inbox');
    if (e.threadId == null) return;
    router.push('/thread/${e.threadId}');
    if (e.action != PushAction.reply || e.messageId == null) return;
    try {
      final message = await ref.read(apiProvider).message(e.messageId!);
      router.push('/compose', extra: ComposeArgs(kind: ComposeKind.reply, source: message, text: e.text));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsProvider).themeMode;
    final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final dark = mode == ThemeMode.dark || (mode == ThemeMode.system && platform == Brightness.dark);
    AppColors.current = dark ? AppColors.dark : AppColors.light;
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(AppColors.current),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      builder: (context, child) => Opening(
        child: KeyedSubtree(key: ValueKey(dark), child: child!),
      ),
    );
  }
}
