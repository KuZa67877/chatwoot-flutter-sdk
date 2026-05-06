import 'package:meta/meta.dart';

import 'chatwoot_message_dto.dart';
import 'chatwoot_public_json.dart';

@immutable
final class ChatwootConversationDto {
  const ChatwootConversationDto({
    required this.id,
    required this.status,
    required this.messages,
  });

  final int id;
  final String status;
  final List<ChatwootMessageDto> messages;

  factory ChatwootConversationDto.fromJson(Json json) {
    return ChatwootConversationDto(
      id: json['id'] as int,
      status: json['status'] as String,
      messages: (json['messages'] as List<dynamic>).map((e) => ChatwootMessageDto.fromJson(e as Json)).toList(),
    );
  }

  Json toJson() => {
    'id': id,
    'status': status,
    'messages': messages.map((e) => e.toJson()).toList(),
  };
}
