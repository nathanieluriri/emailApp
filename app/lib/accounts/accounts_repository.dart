import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account.dart';

class AccountsRepository {
  static const _storage = FlutterSecureStorage();
  static const _accountsKey = 'accounts';
  static const _activeKey = 'active_account';

  Future<List<Account>> load() async {
    final raw = await _storage.read(key: _accountsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Account.fromJson(e)).toList();
  }

  Future<void> save(List<Account> accounts) =>
      _storage.write(key: _accountsKey, value: jsonEncode(accounts.map((a) => a.toJson()).toList()));

  Future<String?> activeId() => _storage.read(key: _activeKey);

  Future<void> setActive(String? id) => id == null ? _storage.delete(key: _activeKey) : _storage.write(key: _activeKey, value: id);
}
