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
    this.contactLastSeenAt = 0,
  });

  final int id;
  final String status;
  final List<ChatwootMessageDto> messages;

  /// Unix seconds (`contact_last_seen_at`). Chatwoot v4.8.0 public conversation JSON.
  final int contactLastSeenAt;

  factory ChatwootConversationDto.fromJson(Json json) {
    final rawSeen = json['contact_last_seen_at'];
    final seenUnix = switch (rawSeen) {
      final int i => i,
      final num n => n.toInt(),
      _ => 0,
    };
    return ChatwootConversationDto(
      id: _parseConversationId(json['id']),
      status: json['status'] as String,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((e) => ChatwootMessageDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      contactLastSeenAt: seenUnix,
    );
  }

  Json toJson() => {
    'id': id,
    'status': status,
    'messages': messages.map((e) => e.toJson()).toList(),
    'contact_last_seen_at': contactLastSeenAt,
  };
}

int _parseConversationId(Object? raw) {
  return switch (raw) {
    final int i => i,
    final num n => n.toInt(),
    _ => throw FormatException('conversation: expected numeric id', raw),
  };
}
