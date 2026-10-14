import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts/accounts_controller.dart';
import '../core/quire/theme/metrics.dart';
import 'mail_repository.dart';
import 'models.dart';

const quickReactions = ['💖', '👍', '🎉', '😂', '🙏', '😊'];

/// Gmail's rules: the mailbox must be on the message, and a reaction goes to at most 20 people.
String? reactionBlocker(Message m, String me) {
  final mine = m.from.address.toLowerCase() == me;
  final listed = {
    for (final a in [...m.to, ...m.cc]) a.address.toLowerCase(),
  };
  final people = {if (!mine) m.from.address.toLowerCase(), ...listed}..remove(me);
  if (m.messageIdHeader == null || people.isEmpty) return "This message can't take reactions";
  if (!mine && !listed.contains(me)) return 'You can only react to mail sent to you directly';
  if (people.length > 20) return "You can't react to a group with an emoji";
  return null;
}

/// The message's reactions with ours that are still on their way, grouped by emoji in the order they were first used.
List<(String, List<Reaction>)> groupedReactions(Message m, List<Reaction> pending) {
  final all = [...m.reactions, ...pending.where((p) => !m.reactions.any((r) => r.mine && r.emoji == p.emoji))];
  final groups = <String, List<Reaction>>{};
  for (final r in all) {
    (groups[r.emoji] ??= []).add(r);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}

/// Our reactions by message id. Each waits out the undo window before it is emailed, and keeps
/// waiting after the thread is closed, the way Gmail holds a send.
class PendingReactions extends Notifier<Map<String, List<Reaction>>> {
  final _waiting = <String, (Timer, Completer<bool>)>{};

  @override
  Map<String, List<Reaction>> build() => const {};

  /// Completes true once sent and false when undone.
  Future<bool> add(Message m, String emoji) {
    final api = ref.read(mailRepositoryProvider).api;
    final account = ref.read(activeAccountProvider);
    final name = account?.displayName ?? '';
    final key = '${m.id} $emoji';
    if (_waiting.containsKey(key) || (state[m.id] ?? const []).any((r) => r.emoji == emoji)) return Future.value(false);
    _set(m.id, [...?state[m.id], Reaction(emoji: emoji, address: account?.email ?? '', name: name, mine: true)]);
    final done = Completer<bool>();
    final timer = Timer(kUndoPill + const Duration(milliseconds: 300), () async {
      _waiting.remove(key);
      try {
        await api.react(m.id, emoji, fromName: name);
        done.complete(true);
      } catch (e, st) {
        _drop(m.id, emoji);
        done.completeError(e, st);
      }
    });
    _waiting[key] = (timer, done);
    return done.future;
  }

  void undo(String messageId, String emoji) {
    final waiting = _waiting.remove('$messageId $emoji');
    if (waiting == null) return;
    waiting.$1.cancel();
    waiting.$2.complete(false);
    _drop(messageId, emoji);
  }

  void _drop(String messageId, String emoji) => _set(messageId, [...?state[messageId]?.where((r) => r.emoji != emoji)]);

  void _set(String messageId, List<Reaction> list) => state = {...state, messageId: list};
}

final pendingReactionsProvider = NotifierProvider<PendingReactions, Map<String, List<Reaction>>>(PendingReactions.new);
