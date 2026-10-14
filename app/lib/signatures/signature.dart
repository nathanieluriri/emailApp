import 'package:json_annotation/json_annotation.dart';

part 'signature.g.dart';

@JsonSerializable()
class Signature {
  const Signature({required this.id, required this.name, this.html = '', this.senderAddress, this.isDefault = false, this.updatedAt});

  final String id;
  final String name;
  @JsonKey(defaultValue: '')
  final String html;
  final String? senderAddress;
  final bool isDefault;
  final int? updatedAt;

  bool appliesTo(String from) => senderAddress == null || senderAddress!.toLowerCase() == from.toLowerCase();

  factory Signature.fromJson(Map<String, dynamic> json) => _$SignatureFromJson(json);
  Map<String, dynamic> toJson() => _$SignatureToJson(this);
}
