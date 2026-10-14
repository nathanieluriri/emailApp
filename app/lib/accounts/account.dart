import 'package:json_annotation/json_annotation.dart';

part 'account.g.dart';

@JsonSerializable()
class Account {
  const Account({required this.id, required this.nickname, required this.workerUrl, required this.apiKey});

  final String id;
  final String nickname;
  final String workerUrl;
  final String apiKey;

  String get host => Uri.parse(workerUrl).host;

  Account copyWith({String? nickname, String? apiKey}) =>
      Account(id: id, nickname: nickname ?? this.nickname, workerUrl: workerUrl, apiKey: apiKey ?? this.apiKey);

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);
  Map<String, dynamic> toJson() => _$AccountToJson(this);
}
