// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Address _$AddressFromJson(Map<String, dynamic> json) => Address(address: json['address'] as String, name: json['name'] as String? ?? '');

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{'address': instance.address, 'name': instance.name};

Attachment _$AttachmentFromJson(Map<String, dynamic> json) => Attachment(
  id: json['id'] as String,
  filename: json['filename'] as String,
  mimeType: json['mimeType'] as String,
  size: (json['size'] as num).toInt(),
  contentId: json['contentId'] as String?,
);

Map<String, dynamic> _$AttachmentToJson(Attachment instance) => <String, dynamic>{
  'id': instance.id,
  'filename': instance.filename,
  'mimeType': instance.mimeType,
  'size': instance.size,
  'contentId': instance.contentId,
};

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String,
  threadId: json['threadId'] as String,
  direction: json['direction'] as String,
  from: Address.fromJson(json['from'] as Map<String, dynamic>),
  to: (json['to'] as List<dynamic>?)?.map((e) => Address.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
  cc: (json['cc'] as List<dynamic>?)?.map((e) => Address.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
  subject: json['subject'] as String? ?? '',
  snippet: json['snippet'] as String? ?? '',
  date: (json['date'] as num).toInt(),
  read: json['read'] as bool? ?? false,
  starred: json['starred'] as bool? ?? false,
  archived: json['archived'] as bool? ?? false,
  hasAttachments: json['hasAttachments'] as bool? ?? false,
  threadCount: (json['threadCount'] as num?)?.toInt() ?? 1,
  labels: (json['labels'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  html: json['html'] as String?,
  text: json['text'] as String?,
  messageIdHeader: json['messageIdHeader'] as String?,
  attachments: (json['attachments'] as List<dynamic>?)?.map((e) => Attachment.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'threadId': instance.threadId,
  'direction': instance.direction,
  'from': instance.from.toJson(),
  'to': instance.to.map((e) => e.toJson()).toList(),
  'cc': instance.cc.map((e) => e.toJson()).toList(),
  'subject': instance.subject,
  'snippet': instance.snippet,
  'date': instance.date,
  'read': instance.read,
  'starred': instance.starred,
  'archived': instance.archived,
  'hasAttachments': instance.hasAttachments,
  'threadCount': instance.threadCount,
  'labels': instance.labels,
  'html': instance.html,
  'text': instance.text,
  'messageIdHeader': instance.messageIdHeader,
  'attachments': instance.attachments.map((e) => e.toJson()).toList(),
};

MailThread _$MailThreadFromJson(Map<String, dynamic> json) => MailThread(
  id: json['id'] as String,
  subject: json['subject'] as String? ?? '',
  messages: (json['messages'] as List<dynamic>).map((e) => Message.fromJson(e as Map<String, dynamic>)).toList(),
);

Map<String, dynamic> _$MailThreadToJson(MailThread instance) => <String, dynamic>{
  'id': instance.id,
  'subject': instance.subject,
  'messages': instance.messages.map((e) => e.toJson()).toList(),
};

MessagePage _$MessagePageFromJson(Map<String, dynamic> json) => MessagePage(
  messages: (json['messages'] as List<dynamic>).map((e) => Message.fromJson(e as Map<String, dynamic>)).toList(),
  nextCursor: json['nextCursor'] as String?,
);

MailLabel _$MailLabelFromJson(Map<String, dynamic> json) => MailLabel(
  id: json['id'] as String,
  name: json['name'] as String,
  color: json['color'] as String?,
  system: json['system'] as bool? ?? false,
  unread: (json['unread'] as num?)?.toInt() ?? 0,
  total: (json['total'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MailLabelToJson(MailLabel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'color': instance.color,
  'system': instance.system,
  'unread': instance.unread,
  'total': instance.total,
};

Sender _$SenderFromJson(Map<String, dynamic> json) => Sender(address: json['address'] as String, name: json['name'] as String);

Senders _$SendersFromJson(Map<String, dynamic> json) => Senders(
  domain: json['domain'] as String,
  senders: (json['senders'] as List<dynamic>).map((e) => Sender.fromJson(e as Map<String, dynamic>)).toList(),
);
