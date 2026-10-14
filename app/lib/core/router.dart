import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/onboarding_screen.dart';
import '../compose/compose_args.dart';
import '../compose/compose_screen.dart';
import '../compose/drafts_screen.dart';
import '../mail/inbox_screen.dart';
import '../mail/outbox_screen.dart';
import '../mail/search_screen.dart';
import '../mail/thread_screen.dart';
import '../settings/account_screen.dart';
import '../settings/settings_screen.dart';
import '../signatures/signature.dart';
import '../signatures/signature_editor.dart';
import '../signatures/signatures_screen.dart';
import '../templates/template.dart';
import '../templates/template_editor.dart';
import '../templates/templates_screen.dart';
import 'motion.dart';
import 'widgets.dart';

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 320),
  transitionsBuilder: (context, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(accountsProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final accounts = ref.read(accountsProvider);
      if (!accounts.hasValue) return state.matchedLocation == '/' ? null : '/';
      final empty = accounts.value!.accounts.isEmpty;
      final onboarding = state.matchedLocation == '/onboarding';
      if (empty && !onboarding) return '/onboarding';
      if (!empty && state.matchedLocation == '/') return '/inbox';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Loader()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, s) => fadeScalePage(s, OnboardingScreen(adding: s.uri.queryParameters['add'] == '1')),
      ),
      GoRoute(path: '/inbox', pageBuilder: (_, s) => _fadePage(s, const InboxScreen())),
      GoRoute(
        path: '/thread/:id',
        pageBuilder: (_, s) => slidePage(s, ThreadScreen(threadId: s.pathParameters['id']!, heroMessageId: s.uri.queryParameters['hero'])),
      ),
      GoRoute(
        path: '/compose',
        pageBuilder: (_, s) {
          final args = s.extra as ComposeArgs? ?? const ComposeArgs();
          final screen = ComposeScreen(args: args);
          return args.kind == ComposeKind.fresh && args.template == null && args.draftId == null
              ? _fadePage(s, screen)
              : padPage(s, screen);
        },
      ),
      GoRoute(path: '/search', pageBuilder: (_, s) => _fadePage(s, const SearchScreen())),
      GoRoute(path: '/drafts', pageBuilder: (_, s) => slidePage(s, const DraftsScreen())),
      GoRoute(path: '/outbox', pageBuilder: (_, s) => slidePage(s, const OutboxScreen())),
      GoRoute(path: '/settings', pageBuilder: (_, s) => slidePage(s, const SettingsScreen())),
      GoRoute(
        path: '/settings/account/:id',
        pageBuilder: (_, s) => slidePage(s, AccountScreen(accountId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/templates',
        pageBuilder: (_, s) => slidePage(s, TemplatesScreen(pick: s.uri.queryParameters['pick'] == '1')),
      ),
      GoRoute(
        path: '/templates/edit',
        pageBuilder: (_, s) => padPage(s, TemplateEditor(template: s.extra as MailTemplate)),
      ),
      GoRoute(path: '/signatures', pageBuilder: (_, s) => slidePage(s, const SignaturesScreen())),
      GoRoute(
        path: '/signatures/edit',
        pageBuilder: (_, s) => padPage(s, SignatureEditor(signature: s.extra as Signature)),
      ),
    ],
  );
});
