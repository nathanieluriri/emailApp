import 'package:json_annotation/json_annotation.dart';

part 'account.g.dart';

/// One sending identity on one worker. The display name travels with every email sent from it.
@JsonSerializable()
class Account {
  const Account({required this.id, required this.email, required this.displayName, required this.workerUrl, required this.apiKey});

  final String id;
  final String email;
  final String displayName;
  final String workerUrl;
  final String apiKey;

  String get host => Uri.parse(workerUrl).host;
  String get name => displayName.isEmpty ? email : displayName;
  String get fromLine => displayName.isEmpty ? email : '$displayName <$email>';

  Account copyWith({String? displayName, String? apiKey, String? workerUrl}) => Account(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    workerUrl: workerUrl ?? this.workerUrl,
    apiKey: apiKey ?? this.apiKey,
  );

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);
  Map<String, dynamic> toJson() => _$AccountToJson(this);
}
