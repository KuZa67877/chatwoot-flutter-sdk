import 'package:meta/meta.dart';

import 'chatwoot_contact_dto.dart';
import 'chatwoot_message_dto.dart';
import 'chatwoot_public_json.dart';

@immutable
final class ChatwootConversationDto {
  const ChatwootConversationDto({
    required this.id,
    required this.uuid,
    required this.inboxId,
    required this.contactLastSeenAt,
    required this.status,
    required this.agentLastSeenAt,
    required this.messages,
    required this.contact,
  });

  final int id;
  final String uuid;
  final int inboxId;
  final int contactLastSeenAt;
  final String status;
  final int agentLastSeenAt;
  final List<ChatwootMessageDto> messages;

  final ChatwootContactDto contact;

  factory ChatwootConversationDto.fromJson(Json json) {
    return ChatwootConversationDto(
      id: json['id'] as int,
      uuid: json['uuid'] as String,
      inboxId: json['inbox_id'] as int,
      contactLastSeenAt: json['contact_last_seen_at'] as int,
      status: json['status'] as String,
      agentLastSeenAt: json['agent_last_seen_at'] as int,
      messages: (json['messages'] as List<dynamic>).map((e) => ChatwootMessageDto.fromJson(e as Json)).toList(),
      contact: ChatwootContactDto.fromJson(json['contact'] as Json),
    );
  }

  Json toJson() => {
    'id': id,
    'uuid': uuid,
    'inbox_id': inboxId,
    'contact_last_seen_at': contactLastSeenAt,
    'status': status,
    'agent_last_seen_at': agentLastSeenAt,
    'messages': messages.map((e) => e.toJson()).toList(),
    'contact': contact.toJson(),
  };
}
