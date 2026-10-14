// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Account _$AccountFromJson(Map<String, dynamic> json) => Account(
  id: json['id'] as String,
  email: json['email'] as String,
  displayName: json['displayName'] as String,
  workerUrl: json['workerUrl'] as String,
  apiKey: json['apiKey'] as String,
);

Map<String, dynamic> _$AccountToJson(Account instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'displayName': instance.displayName,
  'workerUrl': instance.workerUrl,
  'apiKey': instance.apiKey,
};
