import '../mail/models.dart';
import '../templates/template.dart';

enum ComposeKind { fresh, reply, replyAll, forward }

class ComposeArgs {
  const ComposeArgs({this.kind = ComposeKind.fresh, this.source, this.template, this.draftId});
  final ComposeKind kind;
  final Message? source;
  final MailTemplate? template;
  final String? draftId;
}
