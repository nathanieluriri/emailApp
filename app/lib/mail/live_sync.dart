import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts/account.dart';
import '../accounts/accounts_controller.dart';
import '../core/providers.dart';
import 'mail_providers.dart';

enum LiveStatus { paused, connecting, live, offline, polling }

/// While the app is open, a WebSocket to the worker's /live hub for the active mailbox. The hub sends its version on
/// connect and on every change; a version this phone has not seen refreshes the lists, the counts and open threads, so
/// new mail shows up without a pull. In the background the socket closes and push takes over. A server without /live
/// is checked once a minute instead.
class LiveSync extends Notifier<LiveStatus> {
  static const _ping = Duration(seconds: 25);
  static const _poll = Duration(minutes: 1);
  WebSocket? _socket;
  Timer? _retry;
  Timer? _settle;
  int _attempt = 0;
  bool _awake = true;

  @override
  LiveStatus build() {
    final account = ref.watch(activeAccountProvider);
    ref.onDispose(() {
      _awake = false;
      _close();
    });
    if (account == null) return LiveStatus.paused;
    Future.microtask(() => _connect(account));
    return LiveStatus.connecting;
  }

  void pause() {
    _awake = false;
    _close();
    state = LiveStatus.paused;
  }

  void resume() {
    _awake = true;
    if (state == LiveStatus.live || state == LiveStatus.connecting) return;
    _attempt = 0;
    final account = ref.read(activeAccountProvider);
    if (account != null) _connect(account);
  }

  void _close() {
    _retry?.cancel();
    _settle?.cancel();
    _socket?.close();
    _socket = null;
  }

  String get _seenKey => 'live_version_${ref.read(activeAccountProvider)?.id}';

  Future<void> _connect(Account account) async {
    if (!_awake || _socket != null) return;
    _retry?.cancel();
    if (state != LiveStatus.offline) state = LiveStatus.connecting;
    try {
      final url = Uri.parse(account.workerUrl);
      final socket = await WebSocket.connect(
        url.replace(scheme: url.scheme == 'http' ? 'ws' : 'wss', path: '/live').toString(),
        headers: {'Authorization': 'Bearer ${account.apiKey}', 'X-Mailbox': account.email},
      ).timeout(const Duration(seconds: 12));
      if (!_awake || _socket != null) {
        await socket.close();
        return;
      }
      socket.pingInterval = _ping;
      _socket = socket;
      _attempt = 0;
      state = LiveStatus.live;
      void lost() {
        if (identical(_socket, socket)) _lost(account);
      }

      socket.listen(_heard, onDone: lost, onError: (_) => lost(), cancelOnError: true);
    } on WebSocketException {
      if (!_awake) return;
      // The server answered but would not upgrade: it has no /live, so check it on a timer instead.
      state = LiveStatus.polling;
      _refresh();
      _retry = Timer.periodic(_poll, (_) => _refresh());
    } catch (_) {
      if (_socket == null) _lost(account);
    }
  }

  void _lost(Account account) {
    _socket = null;
    if (!_awake) return;
    // A dropped socket usually comes straight back, so only a failed retry counts as offline.
    state = _attempt > 0 ? LiveStatus.offline : LiveStatus.connecting;
    final wait = Duration(seconds: math.min(30, 1 << math.min(_attempt++, 5)));
    _retry = Timer(wait, () => _connect(account));
  }

  void _heard(dynamic data) {
    final version = (jsonDecode('$data') as Map)['version'];
    if (version is! int) return;
    final prefs = ref.read(prefsProvider);
    if (prefs.getInt(_seenKey) == version) return;
    prefs.setInt(_seenKey, version);
    // A burst of changes (a send touches the sender and the thread) refreshes once.
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 250), _refresh);
  }

  void _refresh() {
    ref.invalidate(inboxProvider);
    ref.invalidate(labelsProvider);
    ref.invalidate(threadProvider);
  }
}

final liveSyncProvider = NotifierProvider<LiveSync, LiveStatus>(LiveSync.new);
