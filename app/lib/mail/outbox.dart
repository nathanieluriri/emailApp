import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

import '../accounts/account.dart';
import '../accounts/accounts_controller.dart';
import '../accounts/accounts_repository.dart';
import '../core/api/api_client.dart';
import '../core/background.dart';
import '../core/db/database.dart';
import '../core/providers.dart';
import 'mail_providers.dart';
import 'mail_repository.dart';

/// How long a message waits in the outbox before it leaves, the window in which it can still be taken back.
const outboxHold = Duration(seconds: 4);

/// A message in the outbox: the request the worker will get, where it belongs, and how its attempts went.
class Queued {
  const Queued({
    required this.id,
    required this.accountId,
    required this.body,
    this.sourceId,
    this.threadId,
    this.draft,
    required this.createdAt,
    required this.sendAfter,
    this.attempts = 0,
    this.error,
  });

  factory Queued.of(OutboxItem row) {
    final json = jsonDecode(row.json) as Map<String, dynamic>;
    return Queued(
      id: row.id,
      accountId: row.accountId,
      body: Map<String, dynamic>.from(json['body'] as Map),
      sourceId: json['sourceId'] as String?,
      threadId: json['threadId'] as String?,
      draft: json['draft'] as String?,
      createdAt: row.createdAt,
      sendAfter: row.sendAfter,
      attempts: row.attempts,
      error: row.error,
    );
  }

  final String id;
  final String accountId;

  /// The body for POST /send, or for POST /messages/[sourceId]/reply. Its clientKey is [id], so a retry of a send
  /// that already went through is not sent again.
  final Map<String, dynamic> body;
  final String? sourceId;
  final String? threadId;

  /// The composer's draft, to reopen if the message is taken back.
  final String? draft;
  final int createdAt;

  /// When to try next. Zero holds it until someone retries: the server turned it down.
  final int sendAfter;
  final int attempts;
  final String? error;

  bool get held => sendAfter == 0;
  String? get draftId => draft == null ? null : (jsonDecode(draft!) as Map)['id'] as String?;
  List<Map<String, dynamic>> get attachments => [
    for (final a in body['attachments'] as List? ?? const []) Map<String, dynamic>.from(a as Map),
  ];
  String get subject => '${body['subject'] ?? ''}';
  String get text => '${body['text'] ?? ''}'.trim();
  List<String> get to => [for (final a in body['to'] as List? ?? const []) '$a'];

  Queued after(int attempts, String error, int sendAfter) => Queued(
    id: id,
    accountId: accountId,
    body: body,
    sourceId: sourceId,
    threadId: threadId,
    draft: draft,
    createdAt: createdAt,
    sendAfter: sendAfter,
    attempts: attempts,
    error: error,
  );

  OutboxItemsCompanion get row => OutboxItemsCompanion.insert(
    id: id,
    accountId: accountId,
    json: jsonEncode({'body': body, 'sourceId': sourceId, 'threadId': threadId, 'draft': draft}),
    createdAt: createdAt,
    sendAfter: sendAfter,
    attempts: Value(attempts),
    error: Value(error),
  );
}

/// One try at sending [item]: null once the server has it, or the item as it now stands, to try again later or held
/// for good when the server turned it down.
Future<Queued?> attemptSend(Queued item, ApiClient api) async {
  try {
    final source = item.sourceId;
    source == null ? await api.send(item.body) : await api.reply(source, item.body);
    return null;
  } on ApiException catch (e) {
    final status = e.status ?? 0;
    final refused = status >= 400 && status < 500 && status != 408 && status != 429;
    final attempts = item.attempts + 1;
    final wait = math.min(60000, 2000 * (1 << math.min(attempts - 1, 5)));
    return item.after(attempts, e.message, refused ? 0 : clock.now().millisecondsSinceEpoch + wait);
  }
}

const _backgroundTask = 'outbox-send';

/// Has the phone send the outbox when it is next online, even with the app closed.
Future<void> sendOutboxWhenOnline() async {
  try {
    await ensureBackgroundWork();
    await Workmanager().registerOneOffTask(
      _backgroundTask,
      _backgroundTask,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  } catch (_) {}
}

/// The background half of the outbox: true when nothing is left waiting for the network.
Future<bool> sendOutboxInBackground(String task) async {
  if (task != _backgroundTask) return true;
  final db = AppDatabase();
  try {
    final accounts = {for (final a in await AccountsRepository().load()) a.id: a};
    var done = true;
    for (final item in (await db.outbox()).map(Queued.of)) {
      if (item.held) continue;
      final account = accounts[item.accountId];
      final next = account == null ? null : await attemptSend(item, ApiClient(account.workerUrl, account.apiKey, mailbox: account.email));
      if (next == null) {
        await db.deleteOutbox(item.id);
      } else {
        await db.putOutbox(next.row);
        done = done && next.held;
      }
    }
    return done;
  } finally {
    await db.close();
  }
}

enum OutboxNews { sent, waiting, refused }

class OutboxEvent {
  const OutboxEvent(this.item, this.news);
  final Queued item;
  final OutboxNews news;
}

/// Every message goes through here: it waits out the undo window, then leaves, and keeps trying with backoff until
/// the server has it. Retries also run when the app is opened again, when the connection comes back and, with the app
/// closed, from WorkManager once the phone is online.
class Outbox extends Notifier<List<Queued>> {
  final _sending = <String>{};
  final events = StreamController<OutboxEvent>.broadcast();
  Timer? _timer;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  List<Queued> build() {
    ref.onDispose(() => _timer?.cancel());
    _load();
    return const [];
  }

  bool isSending(String id) => _sending.contains(id);

  Future<void> _load() async {
    state = [for (final row in await _db.outbox()) Queued.of(row)];
    try {
      await ref.read(accountsProvider.future);
    } catch (_) {}
    _schedule();
  }

  Future<String> add(Account account, Map<String, dynamic> body, {String? sourceId, String? threadId, String? draft}) async {
    final now = clock.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    final item = Queued(
      id: id,
      accountId: account.id,
      body: {...body, 'clientKey': id},
      sourceId: sourceId,
      threadId: threadId,
      draft: draft,
      createdAt: now,
      sendAfter: now + outboxHold.inMilliseconds,
    );
    await _db.putOutbox(item.row);
    state = [...state, item];
    _schedule();
    return id;
  }

  /// Takes a message back while it is still in the outbox; null once it has left.
  Future<Queued?> take(String id) async {
    final item = state.where((q) => q.id == id).firstOrNull;
    if (item == null || _sending.contains(id)) return null;
    await _db.deleteOutbox(id);
    state = [
      for (final q in state)
        if (q.id != id) q,
    ];
    _schedule();
    return item;
  }

  Future<void> retry(String id) async {
    final item = state.where((q) => q.id == id).firstOrNull;
    if (item == null) return;
    final now = item.after(item.attempts, item.error ?? '', clock.now().millisecondsSinceEpoch);
    await _db.putOutbox(now.row);
    state = [for (final q in state) q.id == id ? now : q];
    await flush();
  }

  /// Sends what is due. [waiting] also sends what is backing off after a failed try, for when the connection is back.
  Future<void> flush({bool waiting = false}) async {
    if (ref.read(accountsProvider).value == null) return;
    final now = clock.now().millisecondsSinceEpoch;
    final due = state.where((q) => !q.held && (q.sendAfter <= now || (waiting && q.attempts > 0))).toList();
    for (final item in due) {
      await _send(item.id);
    }
    _schedule();
  }

  Future<void> _send(String id) async {
    final item = state.where((q) => q.id == id).firstOrNull;
    if (item == null || _sending.contains(id)) return;
    final account = ref.read(accountsProvider).value?.accounts.where((a) => a.id == item.accountId).firstOrNull;
    _sending.add(id);
    state = [...state];
    final next = account == null ? null : await attemptSend(item, _api(account));
    if (next == null && account != null) await _catchUp(item, account);
    _sending.remove(id);
    if (next == null) {
      await _db.deleteOutbox(item.id);
      state = [
        for (final q in state)
          if (q.id != item.id) q,
      ];
      if (account != null) events.add(OutboxEvent(item, OutboxNews.sent));
      ref.invalidate(inboxProvider);
      ref.invalidate(threadProvider);
      return;
    }
    await _db.putOutbox(next.row);
    state = [for (final q in state) q.id == item.id ? next : q];
    if (next.held) {
      events.add(OutboxEvent(next, OutboxNews.refused));
    } else if (next.attempts == 1) {
      events.add(OutboxEvent(next, OutboxNews.waiting));
    }
  }

  ApiClient _api(Account account) => account.id == ref.read(activeAccountProvider)?.id
      ? ref.read(apiProvider)
      : ApiClient(account.workerUrl, account.apiKey, mailbox: account.email);

  /// Loads an open thread with the sent message in it before its queued card goes, so one takes the other's place.
  Future<void> _catchUp(Queued item, Account account) async {
    final id = item.threadId;
    if (id == null || account.id != ref.read(activeAccountProvider)?.id || !ref.exists(threadProvider(id))) return;
    try {
      await ref.read(mailRepositoryProvider).thread(id).last;
    } catch (_) {}
  }

  void _schedule() {
    _timer?.cancel();
    final times = [
      for (final q in state)
        if (!q.held && !_sending.contains(q.id)) q.sendAfter,
    ];
    if (times.isEmpty) return;
    final wait = times.reduce(math.min) - clock.now().millisecondsSinceEpoch;
    _timer = Timer(Duration(milliseconds: math.max(0, wait)), flush);
  }
}

final outboxProvider = NotifierProvider<Outbox, List<Queued>>(Outbox.new);
