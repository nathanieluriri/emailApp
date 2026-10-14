import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts/accounts_controller.dart';
import 'mail_repository.dart';
import 'models.dart';

class InboxState {
  const InboxState({this.messages = const [], this.nextCursor, this.loadingMore = false, this.offline = false});
  final List<Message> messages;
  final String? nextCursor;
  final bool loadingMore;
  final bool offline;

  InboxState copyWith({List<Message>? messages, String? nextCursor, bool? loadingMore, bool? offline, bool clearCursor = false}) =>
      InboxState(
        messages: messages ?? this.messages,
        nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
        loadingMore: loadingMore ?? this.loadingMore,
        offline: offline ?? this.offline,
      );
}

class InboxController extends AsyncNotifier<InboxState> {
  InboxController(this.label);
  final String label;

  MailRepository get _repo => ref.read(mailRepositoryProvider);

  @override
  Future<InboxState> build() async {
    ref.watch(activeAccountProvider);
    final cached = await _repo.cachedList(label);
    if (cached != null) {
      Future.microtask(refresh);
      return InboxState(messages: cached);
    }
    final page = await _repo.list(label);
    return InboxState(messages: page.messages, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    try {
      final page = await _repo.list(label);
      state = AsyncData(InboxState(messages: page.messages, nextCursor: page.nextCursor));
    } catch (e, st) {
      final current = state.value;
      state = current == null ? AsyncError(e, st) : AsyncData(current.copyWith(offline: true));
      if (current != null) rethrow;
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.nextCursor == null || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _repo.list(label, cursor: current.nextCursor);
      state = AsyncData(InboxState(messages: [...current.messages, ...page.messages], nextCursor: page.nextCursor));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  void _replace(Message m) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(messages: [for (final x in current.messages) x.id == m.id ? m : x]));
  }

  void _remove(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(messages: current.messages.where((x) => x.id != id).toList()));
  }

  Future<void> toggleStar(Message m) async {
    _replace(m.copyWith(starred: !m.starred));
    try {
      await _repo.api.updateThread(m.threadId, starred: !m.starred);
    } catch (_) {
      _replace(m);
      rethrow;
    }
  }

  void markThreadRead(String threadId) {
    final m = state.value?.messages.where((x) => x.threadId == threadId).firstOrNull;
    if (m != null && !m.read) _replace(m.copyWith(read: true));
  }

  Future<void> archive(Message m) => _drop(m, () => _repo.api.updateThread(m.threadId, archived: true));

  Future<void> _drop(Message m, Future<void> Function() action) async {
    final before = state.value;
    _remove(m.id);
    try {
      await action();
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> unarchive(Message m) async {
    await _repo.api.updateThread(m.threadId, archived: false);
    await refresh();
  }
}

final inboxProvider = AsyncNotifierProvider.family<InboxController, InboxState, String>(InboxController.new);

final labelsProvider = FutureProvider<List<MailLabel>>((ref) => ref.watch(mailRepositoryProvider).api.labels());

final currentLabelProvider = NotifierProvider<CurrentLabel, String>(CurrentLabel.new);

class CurrentLabel extends Notifier<String> {
  @override
  String build() {
    ref.watch(activeAccountProvider);
    return 'inbox';
  }

  void select(String label) => state = label;
}

final threadProvider = StreamProvider.family<MailThread, String>((ref, id) => ref.watch(mailRepositoryProvider).thread(id));

final searchProvider = FutureProvider.family<List<Message>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return (await ref.watch(mailRepositoryProvider).api.messages(label: 'all', query: query)).messages;
});

const systemLabels = {'inbox': 'Inbox', 'starred': 'Starred', 'sent': 'Sent', 'all': 'All mail', 'spam': 'Spam', 'trash': 'Trash'};
