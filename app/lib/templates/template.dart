import 'package:json_annotation/json_annotation.dart';

part 'template.g.dart';

@JsonSerializable()
class MailTemplate {
  const MailTemplate({
    required this.id,
    required this.name,
    this.subject,
    this.html,
    this.blocksJson,
    this.variables = const [],
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? subject;
  final String? html;
  @JsonKey(name: 'blocks_json')
  final String? blocksJson;
  final List<String> variables;
  final int? updatedAt;

  factory MailTemplate.fromJson(Map<String, dynamic> json) => _$MailTemplateFromJson(json);
  Map<String, dynamic> toJson() => _$MailTemplateToJson(this);
}
