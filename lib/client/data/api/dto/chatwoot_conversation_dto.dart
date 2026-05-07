import 'package:meta/meta.dart';

import 'chatwoot_message_dto.dart';
import 'chatwoot_public_json.dart';

/// REST [get conversation] and ActionCable [Conversations::EventDataPresenter#push_data] use the same
/// `id` / `status` / `messages` slice (see Chatwoot v4.8.0 public API and widget push payloads).
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
      id: _parseConversationId(json['id']),
      status: json['status'] as String,
      messages: (json['messages'] as List<dynamic>)
          .map((e) => ChatwootMessageDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Json toJson() => {
    'id': id,
    'status': status,
    'messages': messages.map((e) => e.toJson()).toList(),
  };
}

int _parseConversationId(Object? raw) {
  return switch (raw) {
    final int i => i,
    final num n => n.toInt(),
    _ => throw FormatException('conversation: expected numeric id', raw),
  };
}
