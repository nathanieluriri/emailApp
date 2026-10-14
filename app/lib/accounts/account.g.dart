// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Account _$AccountFromJson(Map<String, dynamic> json) => Account(
  id: json['id'] as String,
  nickname: json['nickname'] as String,
  workerUrl: json['workerUrl'] as String,
  apiKey: json['apiKey'] as String,
);

Map<String, dynamic> _$AccountToJson(Account instance) => <String, dynamic>{
  'id': instance.id,
  'nickname': instance.nickname,
  'workerUrl': instance.workerUrl,
  'apiKey': instance.apiKey,
};
