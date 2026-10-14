import 'package:bridgewood_mail/accounts/account.dart';
import 'package:bridgewood_mail/accounts/accounts_controller.dart';
import 'package:bridgewood_mail/app.dart';
import 'package:bridgewood_mail/core/api/api_client.dart';
import 'package:bridgewood_mail/core/db/database.dart';
import 'package:bridgewood_mail/core/providers.dart';
import 'package:bridgewood_mail/core/router.dart';
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

class _Accounts extends AccountsController {
  _Accounts(this.accounts);
  final List<Account> accounts;

  @override
  Future<AccountsState> build() async => AccountsState(accounts: accounts, activeId: accounts.firstOrNull?.id);
}

Future<ProviderContainer> _boot(WidgetTester tester, {required int theme, List<Account> accounts = const [_account, _second]}) async {
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
      apiProvider.overrideWith((ref) => ApiClient('https://w.test', 'k')..dio.httpClientAdapter = FakeWorker()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _shot(WidgetTester tester, String name) => expectLater(find.byType(App), matchesGoldenFile('goldens/$name.png'));

void main() {
  for (final (theme, mode) in [(1, 'light'), (2, 'dark')]) {
    testWidgets('inbox $mode', (tester) async {
      await _boot(tester, theme: theme);
      await _shot(tester, 'inbox_$mode');
      await tester.tap(find.bySemanticsLabel('Menu'));
      await _settle(tester);
      await _shot(tester, 'drawer_$mode');
    });

    testWidgets('thread $mode', (tester) async {
      final c = await _boot(tester, theme: theme);
      c.read(routerProvider).push('/thread/t3?hero=3');
      await _settle(tester);
      await _shot(tester, 'thread_$mode');
    });

    testWidgets('compose $mode', (tester) async {
      final c = await _boot(tester, theme: theme);
      c.read(routerProvider).push('/compose');
      await _settle(tester);
      await _shot(tester, 'compose_$mode');
      final quill = tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;
      quill.document.insert(0, 'Hi Adaeze,\n\nThanks for the comments. Clause 4 works for us; I will send the signed copy on Friday.');
      quill.formatText(0, 10, Attribute.bold);
      await tester.tap(find.bySemanticsLabel('Formatting'));
      await _settle(tester);
      await _shot(tester, 'compose_typing_$mode');
      await tester.tap(find.bySemanticsLabel('More'));
      await _settle(tester);
      await _shot(tester, 'compose_menu_$mode');
    });

    testWidgets('settings $mode', (tester) async {
      final c = await _boot(tester, theme: theme);
      c.read(routerProvider).push('/settings');
      await _settle(tester);
      await _shot(tester, 'settings_$mode');
      c.read(routerProvider).push('/settings/account/a1');
      await _settle(tester);
      await _shot(tester, 'account_$mode');
    });

    testWidgets('onboarding $mode', (tester) async {
      await _boot(tester, theme: theme, accounts: const []);
      await _shot(tester, 'welcome_$mode');
      await tester.tap(find.text('Add account'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).first, 'nathaniel@bridgewoodinvestment.ng');
      await _settle(tester);
      await _shot(tester, 'add_email_$mode');
    });
  }
}
