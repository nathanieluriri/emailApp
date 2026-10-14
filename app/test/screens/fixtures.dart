import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

final _now = DateTime(2026, 10, 14, 12, 30).millisecondsSinceEpoch;
int _ago(int minutes) => _now - minutes * 60000;

Map<String, dynamic> message(
  String id,
  String name,
  String address,
  String subject,
  String snippet,
  int minutesAgo, {
  bool read = false,
  bool starred = false,
  int count = 1,
  bool attachment = false,
  String direction = 'in',
  String? text,
  Map<String, Object>? to,
  List<Map<String, Object>>? participants,
  List<Map<String, Object>>? reactions,
}) => {
  'id': id,
  'threadId': 't$id',
  'direction': direction,
  'from': {'address': address, 'name': name},
  'to': [
    to ?? {'address': 'admin@bridgewoodinvestment.ng', 'name': 'Bridgewood'},
  ],
  'messageIdHeader': '<$id@example.ng>',
  'participants': ?participants,
  'reactions': ?reactions,
  'subject': subject,
  'snippet': snippet,
  'date': _ago(minutesAgo),
  'read': read,
  'starred': starred,
  'archived': false,
  'hasAttachments': attachment,
  'threadCount': count,
  'labels': ['inbox'],
  'text': ?text,
  'attachments': attachment
      ? [
          {'id': 'a1', 'filename': 'Statement-Q3.pdf', 'mimeType': 'application/pdf', 'size': 248000},
        ]
      : [],
};

final inbox = [
  message(
    '1',
    'Tunde Bakare',
    'tunde@lagosrealty.ng',
    'Site visit on Thursday',
    'Can we move the Lekki site visit to 2pm? The contractor is',
    12,
  ),
  message(
    '2',
    'Payments Desk',
    'payments@example.ng',
    'Receipt for NGN 14,000.00',
    'Your payment was received. Reference BW-20931',
    58,
    attachment: true,
  ),
  message(
    '3',
    'Adaeze Okafor',
    'adaeze@okaforlegal.ng',
    'Re: Draft investment agreement',
    'I have added comments to clauses 4 and 7',
    140,
    read: true,
    starred: true,
    count: 3,
    participants: [
      {'address': 'adaeze@okaforlegal.ng', 'name': 'Adaeze Okafor'},
      {'address': 'nathaniel@bridgewoodinvestment.ng', 'name': 'Nathaniel Uriri', 'me': true},
    ],
  ),
  message(
    '4',
    'Cloudflare',
    'noreply@notify.cloudflare.com',
    'Your domain is active',
    'bridgewoodinvestment.ng is now using Cloudflare',
    300,
    read: true,
  ),
  message(
    '5',
    'Ifeoma Nwosu',
    'ifeoma@example.ng',
    'Quarterly report',
    'Attached is the Q3 performance summary for the board',
    1500,
    read: true,
    attachment: true,
  ),
  message(
    '6',
    'Daniel Mensah',
    'daniel@example.com',
    'Lunch next week?',
    'Are you free on Tuesday? There is a new place near',
    2900,
    read: true,
  ),
];

final thread = {
  'id': 't3',
  'subject': 'Re: Draft investment agreement',
  'messages': [
    for (final m in [
      message(
        '3a',
        'Adaeze Okafor',
        'adaeze@okaforlegal.ng',
        'Draft investment agreement',
        'Please find the draft attached.',
        2900,
        read: true,
        text: 'Please find the draft attached.',
      ),
      message(
        '3b',
        'Bridgewood',
        'admin@bridgewoodinvestment.ng',
        'Re: Draft investment agreement',
        'Thanks, reviewing now.',
        1600,
        read: true,
        direction: 'out',
        text: 'Thanks, reviewing now.',
      ),
      message(
        '3c',
        'Adaeze Okafor',
        'adaeze@okaforlegal.ng',
        'Re: Draft investment agreement',
        'I have added comments to clauses 4 and 7',
        140,
        read: true,
        attachment: true,
        to: {'address': 'nathaniel@bridgewoodinvestment.ng', 'name': 'Nathaniel Uriri'},
        reactions: [
          {'emoji': '🎉', 'address': 'nathaniel@bridgewoodinvestment.ng', 'name': 'Nathaniel Uriri', 'mine': true},
          {'emoji': '💖', 'address': 'info@bridgewoodinvestment.ng', 'name': 'Bridgewood Info'},
        ],
        text: 'Hi Nathaniel,\n\nI have added comments to clauses 4 and 7. The rest reads well. Can we close this by Friday?\n\nBest,\nAdaeze\n\nOn Tue, 13 Oct 2026, Bridgewood <admin@bridgewoodinvestment.ng> wrote:\n> Thanks, reviewing now.',
      ),
    ])
      {...m, 'threadId': 't3'},
  ],
};

final labels = [
  {'id': 'inbox', 'name': 'Inbox', 'system': true, 'unread': 2, 'total': 6},
  {'id': 'sent', 'name': 'Sent', 'system': true, 'unread': 0, 'total': 4},
  {'id': 'spam', 'name': 'Spam', 'system': true, 'unread': 1, 'total': 1},
  {'id': 'trash', 'name': 'Trash', 'system': true, 'unread': 0, 'total': 0},
  {'id': 'l1', 'name': 'Clients', 'color': '#21A366', 'system': false, 'unread': 1, 'total': 3},
  {'id': 'l2', 'name': 'Invoices', 'color': '#F5C518', 'system': false, 'unread': 0, 'total': 2},
];

final senders = {
  'domain': 'bridgewoodinvestment.ng',
  'senders': [
    for (final l in ['admin', 'info', 'support', 'noreply']) {'address': '$l@bridgewoodinvestment.ng', 'name': l},
  ],
};

final health = {
  'ok': true,
  'service': 'bridgewood-mail',
  'domain': 'bridgewoodinvestment.ng',
  'routes': ['GET /health'],
  'checks': {'db': true, 'r2': true, 'email': true, 'onesignal': true},
};

class FakeWorker implements HttpClientAdapter {
  static var offline = false;
  static final sent = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (offline) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    final path = options.uri.path;
    if (path == '/send' || path.endsWith('/reply')) sent.add(Map<String, dynamic>.from(options.data as Map));
    final body = switch (path) {
      '/messages' => {'messages': inbox, 'nextCursor': null},
      '/labels' => labels,
      '/senders' => senders,
      '/health' => health,
      '/signatures' => [
        {'id': 's1', 'name': 'Work', 'html': '<b>Nathaniel Uriri</b><br>Bridgewood Investment', 'isDefault': true},
      ],
      '/templates' => [],
      _ when path.startsWith('/threads/') => thread,
      _ when path.endsWith('/react') => {
        'reactions': [
          {'emoji': (options.data as Map)['emoji'], 'mine': true},
        ],
      },
      _ => {'ok': true},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
