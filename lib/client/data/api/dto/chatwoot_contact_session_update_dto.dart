import 'package:meta/meta.dart';

import 'chatwoot_public_json.dart';

@immutable
final class ChatwootContactSessionUpdateDto {
  const ChatwootContactSessionUpdateDto({
    required this.id,
    this.name,
    this.email,
    this.phoneNumber,
  });

  final int id;
  final String? name;
  final String? email;
  final String? phoneNumber;

  factory ChatwootContactSessionUpdateDto.fromJson(Json json) {
    return ChatwootContactSessionUpdateDto(
      id: json['id'] as int,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
    );
  }

  Json toJson() => {
    'id': id,
    'name': ?name,
    'email': ?email,
    'phone_number': ?phoneNumber,
  };
}
