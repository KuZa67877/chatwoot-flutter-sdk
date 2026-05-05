import 'package:meta/meta.dart';

import 'chatwoot_message_dto.dart';
import 'chatwoot_public_json.dart';

/// Conversation fragment from ActionCable push ([Conversations::EventDataPresenter#push_data], v4.8.0).
///
/// Unlike [ChatwootConversationDto], this omits required REST-only fields (e.g. `contact`)
/// and may include only `messages.last` in `messages`.
@immutable
final class ChatwootConversationPushDto {
  const ChatwootConversationPushDto({
    required this.id,
    this.status,
    this.messages = const [],
    this.raw = const {},
  });

  final int id;
  final String? status;
  final List<ChatwootMessageDto> messages;

  /// Original payload for fields not modeled here (meta, timestamps, etc.).
  final Map<String, dynamic> raw;

  factory ChatwootConversationPushDto.fromJson(Json json) {
    final idRaw = json['id'];
    final id = switch (idRaw) {
      final int i => i,
      final num n => n.toInt(),
      _ => throw FormatException('conversation push: missing int id', idRaw),
    };
    final status = json['status'] as String?;
    final messagesRaw = json['messages'] as List<dynamic>?;
    final messages = messagesRaw
            ?.map((e) => ChatwootMessageDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const <ChatwootMessageDto>[];

    return ChatwootConversationPushDto(
      id: id,
      status: status,
      messages: messages,
      raw: Map<String, dynamic>.from(json),
    );
  }
}
