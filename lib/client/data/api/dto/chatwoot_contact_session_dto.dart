import 'package:meta/meta.dart';

import 'chatwoot_public_json.dart';

@immutable
final class ChatwootContactSessionDto {
  const ChatwootContactSessionDto({
    required this.sourceId,
    required this.pubsubToken,
    required this.id,
    this.name,
    this.email,
    this.phoneNumber,
  });

  final String sourceId;
  final String pubsubToken;

  final int id;
  final String? name;
  final String? email;
  final String? phoneNumber;

  factory ChatwootContactSessionDto.fromJson(Json json) {
    return ChatwootContactSessionDto(
      sourceId: json['source_id'] as String,
      pubsubToken: json['pubsub_token'] as String,
      id: json['id'] as int,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
    );
  }

  Json toJson() => {
    'source_id': sourceId,
    'pubsub_token': pubsubToken,
    'id': id,
    'name': ?name,
    'email': ?email,
    'phone_number': ?phoneNumber,
  };
}
