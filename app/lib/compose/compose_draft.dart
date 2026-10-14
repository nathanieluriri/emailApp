import 'package:json_annotation/json_annotation.dart';

part 'compose_draft.g.dart';

@JsonSerializable()
class ComposeDraft {
  const ComposeDraft({
    required this.id,
    this.kind = 'fresh',
    this.sourceId,
    this.from = '',
    this.fromName = '',
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.subject = '',
    this.body = const {},
    this.signatureId,
    this.signatureOff = false,
    this.quoteHtml,
  });

  final String id;
  final String kind;
  final String? sourceId;
  final String from;
  final String fromName;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final Map<String, dynamic> body;
  final String? signatureId;
  final bool signatureOff;
  final String? quoteHtml;

  factory ComposeDraft.fromJson(Map<String, dynamic> json) => _$ComposeDraftFromJson(json);
  Map<String, dynamic> toJson() => _$ComposeDraftToJson(this);
}
