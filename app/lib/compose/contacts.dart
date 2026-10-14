import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts/accounts_controller.dart';
import '../core/providers.dart';
import '../mail/models.dart';

class Contact {
  const Contact(this.address, this.name, {this.you = false});
  final String address;
  final String name;
  final bool you;

  String get display => name.isEmpty ? address : name;
}

/// Everyone this account has mailed with, from the offline cache, most frequent first.
final contactsProvider = FutureProvider.autoDispose<List<Contact>>((ref) async {
  final db = ref.watch(databaseProvider);
  final state = ref.watch(accountsProvider).value;
  final account = state?.active;
  if (account == null) return [];
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final label in ['inbox', 'sent', 'all', 'starred']) {
    final raw = await db.list(account.id, label);
    if (raw == null) continue;
    for (final m in (jsonDecode(raw) as List).map((e) => Message.fromJson(e))) {
      for (final a in [m.from, ...m.to, ...m.cc]) {
        final key = a.address.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
        if (a.name.isNotEmpty) names[key] = a.name;
      }
    }
  }
  final own = {for (final a in state!.accounts) a.email.toLowerCase(): a.displayName};
  final contacts = [
    for (final e in own.entries) Contact(e.key, e.value, you: true),
    for (final key in counts.keys.where((k) => !own.containsKey(k)).toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!)))
      Contact(key, names[key] ?? ''),
  ];
  return contacts;
});
