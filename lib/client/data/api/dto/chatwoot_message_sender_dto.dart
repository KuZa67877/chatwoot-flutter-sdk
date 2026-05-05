import 'package:meta/meta.dart';

import 'chatwoot_public_json.dart';

@immutable
final class ChatwootPublicMessageSenderDto {
  const ChatwootPublicMessageSenderDto({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.thumbnail,
  });

  final int id;
  final String name;
  final String? avatarUrl;
  final String? thumbnail;

  factory ChatwootPublicMessageSenderDto.fromJson(Json json) {
    final name = json['name'] as String? ?? json['available_name'] as String? ?? '';
    return ChatwootPublicMessageSenderDto(
      id: (json['id'] as num).toInt(),
      name: name,
      avatarUrl: json['avatar_url'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  Json toJson() => {
    'id': id,
    'name': name,
    'avatar_url': avatarUrl,
    'thumbnail': thumbnail,
  };
}
