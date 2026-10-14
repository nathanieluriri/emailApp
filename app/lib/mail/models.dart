import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

@JsonSerializable()
class Address {
  const Address({required this.address, this.name = ''});
  final String address;
  final String name;

  String get display => name.isNotEmpty ? name : address;

  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}

@JsonSerializable()
class Attachment {
  const Attachment({required this.id, required this.filename, required this.mimeType, required this.size, this.contentId});
  final String id;
  final String filename;
  final String mimeType;
  final int size;
  final String? contentId;

  bool get isImage => mimeType.startsWith('image/');

  factory Attachment.fromJson(Map<String, dynamic> json) => _$AttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$AttachmentToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Message {
  const Message({
    required this.id,
    required this.threadId,
    required this.direction,
    required this.from,
    this.to = const [],
    this.cc = const [],
    this.subject = '',
    this.snippet = '',
    required this.date,
    this.read = false,
    this.starred = false,
    this.archived = false,
    this.hasAttachments = false,
    this.threadCount = 1,
    this.labels = const [],
    this.html,
    this.text,
    this.messageIdHeader,
    this.attachments = const [],
  });

  final String id;
  final String threadId;
  final String direction;
  final Address from;
  final List<Address> to;
  final List<Address> cc;
  @JsonKey(defaultValue: '')
  final String subject;
  @JsonKey(defaultValue: '')
  final String snippet;
  final int date;
  final bool read;
  final bool starred;
  final bool archived;
  final bool hasAttachments;
  final int threadCount;
  final List<String> labels;
  final String? html;
  final String? text;
  final String? messageIdHeader;
  final List<Attachment> attachments;

  bool get outgoing => direction == 'out';
  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(date);

  Message copyWith({bool? read, bool? starred, bool? archived, List<String>? labels}) => Message(
    id: id,
    threadId: threadId,
    direction: direction,
    from: from,
    to: to,
    cc: cc,
    subject: subject,
    snippet: snippet,
    date: date,
    read: read ?? this.read,
    starred: starred ?? this.starred,
    archived: archived ?? this.archived,
    hasAttachments: hasAttachments,
    threadCount: threadCount,
    labels: labels ?? this.labels,
    html: html,
    text: text,
    messageIdHeader: messageIdHeader,
    attachments: attachments,
  );

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MailThread {
  const MailThread({required this.id, this.subject = '', required this.messages});
  final String id;
  @JsonKey(defaultValue: '')
  final String subject;
  final List<Message> messages;

  factory MailThread.fromJson(Map<String, dynamic> json) => _$MailThreadFromJson(json);
  Map<String, dynamic> toJson() => _$MailThreadToJson(this);
}

@JsonSerializable(createToJson: false)
class MessagePage {
  const MessagePage({required this.messages, this.nextCursor});
  final List<Message> messages;
  final String? nextCursor;

  factory MessagePage.fromJson(Map<String, dynamic> json) => _$MessagePageFromJson(json);
}

@JsonSerializable()
class MailLabel {
  const MailLabel({required this.id, required this.name, this.color, this.system = false, this.unread = 0, this.total = 0});
  final String id;
  final String name;
  final String? color;
  final bool system;
  final int unread;
  final int total;

  factory MailLabel.fromJson(Map<String, dynamic> json) => _$MailLabelFromJson(json);
  Map<String, dynamic> toJson() => _$MailLabelToJson(this);
}

@JsonSerializable(createToJson: false)
class Sender {
  const Sender({required this.address, required this.name});
  final String address;
  final String name;

  String get localPart => address.split('@').first;

  factory Sender.fromJson(Map<String, dynamic> json) => _$SenderFromJson(json);
}

@JsonSerializable(createToJson: false)
class Senders {
  const Senders({required this.domain, required this.senders});
  final String domain;
  final List<Sender> senders;

  factory Senders.fromJson(Map<String, dynamic> json) => _$SendersFromJson(json);
}
