// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compose_draft.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComposeDraft _$ComposeDraftFromJson(Map<String, dynamic> json) => ComposeDraft(
  id: json['id'] as String,
  kind: json['kind'] as String? ?? 'fresh',
  sourceId: json['sourceId'] as String?,
  from: json['from'] as String? ?? '',
  fromName: json['fromName'] as String? ?? '',
  to: (json['to'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  cc: (json['cc'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  bcc: (json['bcc'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  subject: json['subject'] as String? ?? '',
  body: json['body'] as Map<String, dynamic>? ?? const {},
  signatureId: json['signatureId'] as String?,
  signatureOff: json['signatureOff'] as bool? ?? false,
  quoteHtml: json['quoteHtml'] as String?,
);

Map<String, dynamic> _$ComposeDraftToJson(ComposeDraft instance) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'sourceId': instance.sourceId,
  'from': instance.from,
  'fromName': instance.fromName,
  'to': instance.to,
  'cc': instance.cc,
  'bcc': instance.bcc,
  'subject': instance.subject,
  'body': instance.body,
  'signatureId': instance.signatureId,
  'signatureOff': instance.signatureOff,
  'quoteHtml': instance.quoteHtml,
};
