// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signature.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Signature _$SignatureFromJson(Map<String, dynamic> json) => Signature(
  id: json['id'] as String,
  name: json['name'] as String,
  html: json['html'] as String? ?? '',
  senderAddress: json['senderAddress'] as String?,
  isDefault: json['isDefault'] as bool? ?? false,
  updatedAt: (json['updatedAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$SignatureToJson(Signature instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'html': instance.html,
  'senderAddress': instance.senderAddress,
  'isDefault': instance.isDefault,
  'updatedAt': instance.updatedAt,
};
