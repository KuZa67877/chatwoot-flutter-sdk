import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_contact_merged_push_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_push_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_public_json.dart';
import 'package:meta/meta.dart';

/// Внутреннее представление известных ActionCable-событий (SDK не отдаёт наружу).
///
/// Envelope: `{ event: name, data: { ... } }` ([ActionCableBroadcastJob] v4.8.0).
sealed class ChatwootEvent {
  const ChatwootEvent();

  factory ChatwootEvent.fromEnvelope(
    String event,
    Map<String, dynamic> data,
  ) {
    final json = Map<String, dynamic>.from(data);
    try {
      return switch (event) {
        'message.created' => ChatwootMessageCreatedEvent(ChatwootMessageDto.fromJson(json)),
        'message.updated' => ChatwootMessageUpdatedEvent(
          message: ChatwootMessageDto.fromJson(json),
          previousChanges: _previousChanges(json),
        ),
        'conversation.created' => ChatwootConversationCreatedEvent(ChatwootConversationPushDto.fromJson(json)),
        'conversation.status_changed' => ChatwootConversationStatusChangedEvent(
          ChatwootConversationPushDto.fromJson(json),
        ),
        'contact.merged' => ChatwootContactMergedEvent(ChatwootContactMergedPushDto.fromJson(json)),
        _ => ChatwootUnknownEvent(event, json),
      };
    } on FormatException catch (_) {
      return ChatwootUnknownEvent(event, json);
    } catch (_) {
      return ChatwootUnknownEvent(event, json);
    }
  }
}

/// [message.created](https://github.com/chatwoot/chatwoot/blob/v4.8.0/lib/events/types.rb)
final class ChatwootMessageCreatedEvent extends ChatwootEvent {
  const ChatwootMessageCreatedEvent(this.message);
  final ChatwootMessageDto message;
}

/// [message.updated]
final class ChatwootMessageUpdatedEvent extends ChatwootEvent {
  const ChatwootMessageUpdatedEvent({
    required this.message,
    this.previousChanges,
  });

  final ChatwootMessageDto message;

  /// Rails [previous_changes] slice when present on the broadcast payload.
  final Map<String, dynamic>? previousChanges;
}

/// [conversation.created]
final class ChatwootConversationCreatedEvent extends ChatwootEvent {
  const ChatwootConversationCreatedEvent(this.conversation);
  final ChatwootConversationPushDto conversation;
}

/// [conversation.status_changed]
final class ChatwootConversationStatusChangedEvent extends ChatwootEvent {
  const ChatwootConversationStatusChangedEvent(this.conversation);
  final ChatwootConversationPushDto conversation;
}

/// [contact.merged] (when delivered on this connection).
final class ChatwootContactMergedEvent extends ChatwootEvent {
  const ChatwootContactMergedEvent(this.merge);
  final ChatwootContactMergedPushDto merge;
}

/// Прочие имена событий или ошибка разбора известного payload.
@immutable
final class ChatwootUnknownEvent extends ChatwootEvent {
  const ChatwootUnknownEvent(this.name, this.data);
  final String name;
  final Map<String, dynamic> data;
}

Map<String, dynamic>? _previousChanges(Json json) {
  final prev = json['previous_changes'];
  if (prev is Map) {
    return Map<String, dynamic>.from(prev);
  }
  return null;
}
