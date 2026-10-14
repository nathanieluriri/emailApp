// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MailTemplate _$MailTemplateFromJson(Map<String, dynamic> json) => MailTemplate(
  id: json['id'] as String,
  name: json['name'] as String,
  subject: json['subject'] as String?,
  html: json['html'] as String?,
  blocksJson: json['blocks_json'] as String?,
  variables: (json['variables'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  updatedAt: (json['updatedAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$MailTemplateToJson(MailTemplate instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'subject': instance.subject,
  'html': instance.html,
  'blocks_json': instance.blocksJson,
  'variables': instance.variables,
  'updatedAt': instance.updatedAt,
};
