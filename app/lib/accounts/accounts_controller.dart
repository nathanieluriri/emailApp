import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/providers.dart';
import '../notifications/push_service.dart';
import 'account.dart';
import 'accounts_repository.dart';

class AccountsState {
  const AccountsState({this.accounts = const [], this.activeId});
  final List<Account> accounts;
  final String? activeId;

  Account? get active => accounts.where((a) => a.id == activeId).firstOrNull ?? accounts.firstOrNull;
}

class AccountsController extends AsyncNotifier<AccountsState> {
  final _repo = AccountsRepository();

  @override
  Future<AccountsState> build() async {
    final accounts = await _repo.load();
    PushService.register(accounts).ignore();
    return AccountsState(accounts: accounts, activeId: await _repo.activeId());
  }

  Future<void> _commit(AccountsState next, {Account? removed}) async {
    await _repo.save(next.accounts);
    await _repo.setActive(next.active?.id);
    state = AsyncData(next);
    PushService.register(next.accounts, removed: removed).ignore();
  }

  Future<void> add(Account account) async {
    final current = state.value ?? const AccountsState();
    await _commit(AccountsState(accounts: [...current.accounts.where((a) => a.id != account.id), account], activeId: account.id));
  }

  Future<void> switchTo(String id) async {
    final current = state.requireValue;
    if (current.activeId == id) return;
    await _commit(AccountsState(accounts: current.accounts, activeId: id));
  }

  Future<void> replace(Account account) async {
    final current = state.requireValue;
    await _commit(
      AccountsState(accounts: [for (final a in current.accounts) a.id == account.id ? account : a], activeId: current.activeId),
    );
  }

  Future<void> remove(String id) async {
    final current = state.requireValue;
    final removed = current.accounts.firstWhere((a) => a.id == id);
    final rest = current.accounts.where((a) => a.id != id).toList();
    await ref.read(databaseProvider).forgetAccount(id);
    await _commit(
      AccountsState(accounts: rest, activeId: current.activeId == id ? rest.firstOrNull?.id : current.activeId),
      removed: removed,
    );
  }

  Account? forPush(String host, String? address) {
    final onHost = state.value?.accounts.where((a) => a.host == host) ?? const <Account>[];
    return onHost.where((a) => a.email.toLowerCase() == address?.toLowerCase()).firstOrNull ?? onHost.firstOrNull;
  }
}

final accountsProvider = AsyncNotifierProvider<AccountsController, AccountsState>(AccountsController.new);

final activeAccountProvider = Provider<Account?>((ref) => ref.watch(accountsProvider).value?.active);

final apiProvider = Provider<ApiClient>((ref) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw StateError('No account');
  return ApiClient(account.workerUrl, account.apiKey, mailbox: account.email);
});
