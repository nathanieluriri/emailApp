import 'package:bridgewood_mail/accounts/account.dart';
import 'package:bridgewood_mail/accounts/accounts_controller.dart';
import 'package:bridgewood_mail/app.dart';
import 'package:bridgewood_mail/compose/compose_args.dart';
import 'package:bridgewood_mail/mail/models.dart';
import 'package:bridgewood_mail/core/api/api_client.dart';
import 'package:bridgewood_mail/core/db/database.dart';
import 'package:bridgewood_mail/core/providers.dart';
import 'package:bridgewood_mail/core/router.dart';
import 'package:bridgewood_mail/notifications/push_service.dart';
import 'package:bridgewood_mail/notifications/push_status.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const _account = Account(
  id: 'a1',
  email: 'nathaniel@bridgewoodinvestment.ng',
  displayName: 'Nathaniel Uriri',
  workerUrl: 'https://bridgewood-mail.example.workers.dev',
  apiKey: 'k',
);
const _second = Account(
  id: 'a2',
  email: 'info@bridgewoodinvestment.ng',
  displayName: 'Bridgewood Info',
  workerUrl: 'https://bridgewood-mail.example.workers.dev',
  apiKey: 'k',
);

const _subscribed = PushStatus(
  permission: true,
  optedIn: true,
  id: '8f2c41d7-5b1e-4c9a-a7e3-0d6b9f12c3aa',
  token: 't',
  linked: {'nathaniel@bridgewoodinvestment.ng', 'info@bridgewoodinvestment.ng'},
);

class _Push extends PushStatusController {
  _Push(this.status);
  final PushStatus status;

  @override
  PushStatus build() => status;
}

class _Accounts extends AccountsController {
  _Accounts(this.accounts);
  final List<Account> accounts;

  @override
  Future<AccountsState> build() async => AccountsState(accounts: accounts, activeId: accounts.firstOrNull?.id);
}

Future<ProviderContainer> boot(
  WidgetTester tester, {
  required int theme,
  List<Account> accounts = const [_account, _second],
  PushStatus push = _subscribed,
  bool settled = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'theme_mode': theme});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
      accountsProvider.overrideWith(() => _Accounts(accounts)),
      pushStatusProvider.overrideWith(() => _Push(push)),
      apiProvider.overrideWith((ref) => ApiClient('https://w.test', 'k')..dio.httpClientAdapter = FakeWorker()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
  if (settled) await settle(tester);
  return container;
}

Future<ProviderContainer> bootQuiet(WidgetTester tester) => boot(tester, theme: 2, settled: false);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _shot(WidgetTester tester, String name) => expectLater(find.byType(App), matchesGoldenFile('goldens/$name.png'));

void main() {
  for (final (theme, mode) in [(1, 'light'), (2, 'dark')]) {
    testWidgets('inbox $mode', (tester) async {
      await boot(tester, theme: theme);
      await _shot(tester, 'inbox_$mode');
      await tester.tap(find.bySemanticsLabel('Actions'));
      await settle(tester);
      await _shot(tester, 'fab_open_$mode');
      await tester.tapAt(const Offset(40, 400));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Menu'));
      await settle(tester);
      await _shot(tester, 'drawer_$mode');
    });

    testWidgets('push $mode', (tester) async {
      await boot(tester, theme: theme, push: const PushStatus());
      await _shot(tester, 'inbox_push_off_$mode');
      PushService.events.add(
        const PushEvent(
          host: 'bridgewood-mail.example.workers.dev',
          threadId: 't3',
          sender: 'Adaeze Okafor',
          subject: 'Re: Lease renewal for Lekki office',
          snippet: 'Clause 4 works for us. Could you send the signed copy by Friday so we can file it?',
          account: 'nathaniel@bridgewoodinvestment.ng',
          opened: false,
        ),
      );
      await settle(tester);
      await _shot(tester, 'banner_$mode');
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
    });

    testWidgets('thread $mode', (tester) async {
      final c = await boot(tester, theme: theme);
      c.read(routerProvider).push('/thread/t3?hero=3');
      await settle(tester);
      await _shot(tester, 'thread_$mode');
      await tester.tap(find.text('to me'));
      await tester.tap(find.text('Show quoted text'));
      await settle(tester);
      await _shot(tester, 'thread_details_$mode');
      await tester.tap(find.bySemanticsLabel('More').first);
      await settle(tester);
      await _shot(tester, 'thread_menu_$mode');
    });

    testWidgets('reactions $mode', (tester) async {
      final c = await boot(tester, theme: theme);
      c.read(routerProvider).push('/thread/t3?hero=3');
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Add reaction').last);
      await settle(tester);
      await _shot(tester, 'reaction_bar_$mode');
      await tester.tap(find.bySemanticsLabel('React with 😂'));
      await settle(tester);
      await _shot(tester, 'reacted_$mode');
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      expect(find.bySemanticsLabel('😂 1'), findsOneWidget);
    });

    testWidgets('compose $mode', (tester) async {
      final c = await boot(tester, theme: theme);
      c.read(routerProvider).push('/compose');
      await settle(tester);
      await _shot(tester, 'compose_$mode');
      final quill = tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;
      quill.document.insert(0, 'Hi Adaeze,\n\nThanks for the comments. Clause 4 works for us; I will send the signed copy on Friday.');
      quill.formatText(0, 10, Attribute.bold);
      await tester.tap(find.byType(QuillEditor));
      await settle(tester);
      await _shot(tester, 'compose_typing_$mode');
      await tester.tap(find.bySemanticsLabel('More'));
      await settle(tester);
      await _shot(tester, 'compose_menu_$mode');
    });

    testWidgets('reply $mode', (tester) async {
      final c = await boot(tester, theme: theme);
      final source = Message.fromJson((thread['messages']! as List)[2] as Map<String, dynamic>);
      c
          .read(routerProvider)
          .push(
            '/compose',
            extra: ComposeArgs(kind: ComposeKind.replyAll, source: source),
          );
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Show Cc and Bcc'));
      await settle(tester);
      await _shot(tester, 'reply_$mode');
    });

    testWidgets('sent folder opens threads after the drawer closes', (tester) async {
      final c = await boot(tester, theme: theme);
      await tester.tap(find.bySemanticsLabel('Menu'));
      await settle(tester);
      await tester.tap(find.text('Sent'));
      await settle(tester);
      await tester.tap(find.text('Site visit on Thursday'));
      await settle(tester);
      expect(c.read(routerProvider).state.matchedLocation, startsWith('/thread/'));
    });

    testWidgets('settings $mode', (tester) async {
      final c = await boot(tester, theme: theme);
      c.read(routerProvider).push('/settings');
      await settle(tester);
      await _shot(tester, 'settings_$mode');
      c.read(routerProvider).push('/settings/account/a1');
      await settle(tester);
      await _shot(tester, 'account_$mode');
    });

    testWidgets('settings without a push id $mode', (tester) async {
      final c = await boot(tester, theme: theme, push: const PushStatus(permission: true, optedIn: true));
      c.read(routerProvider).push('/settings');
      await settle(tester);
      await _shot(tester, 'settings_push_$mode');
    });

    testWidgets('onboarding $mode', (tester) async {
      await boot(tester, theme: theme, accounts: const []);
      await _shot(tester, 'welcome_$mode');
      await tester.tap(find.text('Add account'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'nathaniel@bridgewoodinvestment.ng');
      await settle(tester);
      await _shot(tester, 'add_email_$mode');
    });
  }
}
