import '../mail/models.dart';
import '../templates/template.dart';

enum ComposeKind { fresh, reply, replyAll, forward }

class ComposeArgs {
  const ComposeArgs({
    this.kind = ComposeKind.fresh,
    this.source,
    this.template,
    this.draftId,
    this.design = false,
    this.text,
    this.attachments = const [],
    this.threadId,
  });
  final ComposeKind kind;
  final Message? source;

  /// Plain text to start the body with.
  final String? text;

  /// Files to start with, as the worker takes them: {filename, type, content (base64)}. A message taken back from the
  /// outbox brings its attachments back this way.
  final List<Map<String, dynamic>> attachments;

  /// The conversation a reply reopened from the outbox belongs to, where it waits while it sends.
  final String? threadId;
  final MailTemplate? template;
  final String? draftId;
  final bool design;
}
