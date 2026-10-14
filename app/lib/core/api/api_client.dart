import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../mail/models.dart';
import '../../signatures/signature.dart';
import '../../templates/template.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;

  factory ApiException.from(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final data = e.response?.data;
      final msg = data is Map && data['error'] != null
          ? '${data['error']}'
          : switch (e.type) {
              DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout => 'The worker took too long to answer',
              DioExceptionType.connectionError => 'No connection to the worker',
              _ => e.message ?? 'Request failed',
            };
      return ApiException(msg, e.response?.statusCode);
    }
    return ApiException('$e');
  }

  @override
  String toString() => message;
}

/// With a [mailbox], the worker only returns and pushes mail that address received or sent.
class ApiClient {
  ApiClient(String baseUrl, String? apiKey, {String? mailbox})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {if (apiKey != null) 'Authorization': 'Bearer $apiKey', 'X-Mailbox': ?mailbox},
        ),
      );

  final Dio dio;

  Future<T> _call<T>(Future<Response> Function() request, T Function(dynamic data) parse) async {
    try {
      return parse((await request()).data);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<Map<String, dynamic>> health() => _call(() => dio.get('/health'), (d) => Map<String, dynamic>.from(d));

  Future<Senders> senders() => _call(() => dio.get('/senders'), (d) => Senders.fromJson(d));

  Future<MessagePage> messages({String label = 'inbox', String? query, bool unread = false, String? cursor}) => _call(
    () => dio.get(
      '/messages',
      queryParameters: {'label': label, if (query != null && query.isNotEmpty) 'q': query, if (unread) 'unread': '1', 'cursor': ?cursor},
    ),
    (d) => MessagePage.fromJson(d),
  );

  Future<Message> message(String id) => _call(() => dio.get('/messages/$id'), (d) => Message.fromJson(d));

  Future<MailThread> thread(String id) => _call(() => dio.get('/threads/$id'), (d) => MailThread.fromJson(d));

  Future<Message> updateMessage(String id, {bool? read, bool? starred, bool? archived, List<String>? labels}) => _call(
    () => dio.patch('/messages/$id', data: {'read': ?read, 'starred': ?starred, 'archived': ?archived, 'labels': ?labels}),
    (d) => Message.fromJson(d),
  );

  /// Acts on every message of a conversation this mailbox can see. Starring stars the newest message.
  Future<void> updateThread(String id, {bool? read, bool? starred, bool? archived, List<String>? add, List<String>? remove}) => _call(
    () => dio.patch('/threads/$id', data: {'read': ?read, 'starred': ?starred, 'archived': ?archived, 'add': ?add, 'remove': ?remove}),
    (_) {},
  );

  /// Sends a Gmail-style reaction to everyone on the message and returns its reactions.
  Future<List<Reaction>> react(String messageId, String emoji, {String fromName = ''}) => _call(
    () => dio.post('/messages/$messageId/react', data: {'emoji': emoji, 'fromName': fromName}),
    (d) => [for (final r in d['reactions'] as List) Reaction.fromJson(r)],
  );

  Future<Uint8List> attachment(String id) => _call(
    () => dio.get('/attachments/$id', options: Options(responseType: ResponseType.bytes)),
    (d) => Uint8List.fromList(d as List<int>),
  );

  Future<List<MailLabel>> labels() => _call(() => dio.get('/labels'), (d) => (d as List).map((e) => MailLabel.fromJson(e)).toList());

  Future<MailLabel> createLabel(String name, String? color) =>
      _call(() => dio.post('/labels', data: {'name': name, 'color': color}), (d) => MailLabel.fromJson(d));

  Future<MailLabel> updateLabel(String id, {String? name, String? color}) =>
      _call(() => dio.patch('/labels/$id', data: {'name': ?name, 'color': ?color}), (d) => MailLabel.fromJson(d));

  Future<void> deleteLabel(String id) => _call(() => dio.delete('/labels/$id'), (_) {});

  Future<Map<String, dynamic>> send(Map<String, dynamic> body) =>
      _call(() => dio.post('/send', data: body), (d) => Map<String, dynamic>.from(d));

  Future<Map<String, dynamic>> reply(String messageId, Map<String, dynamic> body) =>
      _call(() => dio.post('/messages/$messageId/reply', data: body), (d) => Map<String, dynamic>.from(d));

  Future<List<MailTemplate>> templates() =>
      _call(() => dio.get('/templates'), (d) => (d as List).map((e) => MailTemplate.fromJson(e)).toList());

  Future<MailTemplate> saveTemplate(MailTemplate t, {bool create = false}) => _call(
    () => create ? dio.post('/templates', data: t.toJson()) : dio.patch('/templates/${t.id}', data: t.toJson()),
    (d) => MailTemplate.fromJson(d),
  );

  Future<void> deleteTemplate(String id) => _call(() => dio.delete('/templates/$id'), (_) {});

  Future<List<Signature>> signatures() =>
      _call(() => dio.get('/signatures'), (d) => (d as List).map((e) => Signature.fromJson(e)).toList());

  Future<Signature> saveSignature(Signature s, {bool create = false}) => _call(
    () => create ? dio.post('/signatures', data: s.toJson()) : dio.patch('/signatures/${s.id}', data: s.toJson()),
    (d) => Signature.fromJson(d),
  );

  Future<void> deleteSignature(String id) => _call(() => dio.delete('/signatures/$id'), (_) {});

  Future<String> uploadImage(Uint8List bytes, String mimeType) => _call(
    () => dio.post(
      '/uploads',
      data: Stream.fromIterable([bytes]),
      options: Options(contentType: mimeType, headers: {Headers.contentLengthHeader: bytes.length}),
    ),
    (d) => '${d['url']}',
  );

  Future<Map<String, dynamic>> catchAll() => _call(() => dio.get('/routing/catch-all'), (d) => Map<String, dynamic>.from(d));

  Future<Map<String, dynamic>> setCatchAll(bool toWorker) =>
      _call(() => dio.put('/routing/catch-all', data: {'toWorker': toWorker}), (d) => Map<String, dynamic>.from(d));

  /// Returns the addresses the worker pushes to [device] for.
  Future<List<String>> testPush(String device) =>
      _call(() => dio.post('/push/test', data: {'device': device}), (d) => [...(d['linked'] as List? ?? const []).cast<String>()]);

  /// [utcOffset] (minutes) lets the worker remind about unread mail in this phone's daytime; [remind] turns that off.
  Future<List<String>> registerDevice(
    String device,
    Iterable<String> addresses, {
    String? subscriptionId,
    int utcOffset = 0,
    bool remind = true,
  }) => _call(
    () => dio.put(
      '/devices/$device',
      data: {
        'addresses': [...addresses],
        'subscriptionId': ?subscriptionId,
        'utcOffset': utcOffset,
        'remind': remind,
      },
    ),
    (d) => [...(d['addresses'] as List? ?? const []).cast<String>()],
  );
}
