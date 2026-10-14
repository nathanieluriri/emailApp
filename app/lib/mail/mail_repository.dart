import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts/accounts_controller.dart';
import '../core/api/api_client.dart';
import '../core/db/database.dart';
import '../core/providers.dart';
import 'models.dart';

class MailRepository {
  MailRepository(this.api, this.db, this.accountId);
  final ApiClient api;
  final AppDatabase db;
  final String accountId;

  Future<List<Message>?> cachedList(String label) async {
    final raw = await db.list(accountId, label);
    return raw == null ? null : (jsonDecode(raw) as List).map((e) => Message.fromJson(e)).toList();
  }

  Future<MessagePage> list(String label, {String? cursor}) async {
    final page = await api.messages(label: label, cursor: cursor);
    if (cursor == null) await db.putList(accountId, label, jsonEncode(page.messages.map((m) => m.toJson()).toList()));
    return page;
  }

  Stream<MailThread> thread(String id) async* {
    final cached = await db.thread(accountId, id);
    if (cached != null) yield MailThread.fromJson(jsonDecode(cached));
    try {
      final fresh = await api.thread(id);
      await db.putThread(accountId, id, jsonEncode(fresh.toJson()));
      yield fresh;
    } catch (e) {
      if (cached == null) rethrow;
    }
  }
}

final mailRepositoryProvider = Provider<MailRepository>(
  (ref) => MailRepository(ref.watch(apiProvider), ref.watch(databaseProvider), ref.watch(activeAccountProvider)!.id),
);
