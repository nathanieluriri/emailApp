import '../mail/models.dart';
import '../templates/template.dart';

enum ComposeKind { fresh, reply, replyAll, forward }

class ComposeArgs {
  const ComposeArgs({this.kind = ComposeKind.fresh, this.source, this.template, this.draftId, this.design = false});
  final ComposeKind kind;
  final Message? source;
  final MailTemplate? template;
  final String? draftId;
  final bool design;
}
