import 'package:meta/meta.dart';

import 'chatwoot_attachment_dto.dart';
import 'chatwoot_message_sender_dto.dart';
import 'chatwoot_public_json.dart';

@immutable
final class ChatwootMessageDto {
  const ChatwootMessageDto({
    required this.id,
    this.content,
    this.echoId,
    required this.messageType,
    required this.contentAttributes,
    required this.createdAt,
    required this.conversationId,
    this.attachments = const [],
    this.sender,
  });

  factory ChatwootMessageDto.fromJson(Json json) {
    return ChatwootMessageDto(
      id: json['id'] as int,
      echoId: json['echo_id'] as String?,
      content: json['content'] as String?,
      messageType: json['message_type'] as int,
      contentAttributes: Map<String, dynamic>.from(json['content_attributes'] as Map? ?? const {}),
      createdAt: json['created_at'] as int,
      conversationId: json['conversation_id'] as int,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => ChatwootAttachmentDto.fromJson(e as Json))
              .toList() ??
          const [],
      sender: json['sender'] != null ? ChatwootPublicMessageSenderDto.fromJson(json['sender'] as Json) : null,
    );
  }

  final int id;
  final String? echoId;
  final String? content;

  final int messageType;

  final Json contentAttributes;
  final int createdAt;
  final int conversationId;
  final List<ChatwootAttachmentDto> attachments;
  final ChatwootPublicMessageSenderDto? sender;

  Json toJson() => {
    'id': id,
    if (content != null) 'content': content,
    if (echoId != null) 'echo_id': echoId,
    'message_type': messageType,
    'content_attributes': Map<String, dynamic>.from(contentAttributes),
    'created_at': createdAt,
    'conversation_id': conversationId,
    if (attachments.isNotEmpty) 'attachments': attachments.map((e) => e.toJson()).toList(),
    if (sender != null) 'sender': sender!.toJson(),
  };
}
