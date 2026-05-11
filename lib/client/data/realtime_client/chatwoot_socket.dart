import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_dto.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_connection_state.dart';

/// Low-level ActionCable/WebSocket port (DTO wire shapes).
///
/// Domain-facing realtime API lives on [ChatwootCable] in `client/domain/data/`.
abstract interface class ChatwootSocket {
  Stream<ChatwootConnectionState> get connectionState;

  Stream<ChatwootSocketEvent> get events;

  Future<void> connect({
    required String sourceId,
    required String pubsubToken,
  });

  Future<void> markPresence();

  Future<void> disconnect();
}

sealed class ChatwootSocketEvent {
  const ChatwootSocketEvent();
}

sealed class ChatwootSocketEvent$Message extends ChatwootSocketEvent {
  const ChatwootSocketEvent$Message({
    required this.message,
  });

  final ChatwootMessageDto message;
}

class ChatwootSocketEvent$Message$Created extends ChatwootSocketEvent$Message {
  const ChatwootSocketEvent$Message$Created({
    required super.message,
  });
}

class ChatwootSocketEvent$Message$Updated extends ChatwootSocketEvent$Message {
  const ChatwootSocketEvent$Message$Updated({
    required super.message,
  });
}

sealed class ChatwootSocketEvent$Conversation extends ChatwootSocketEvent {
  const ChatwootSocketEvent$Conversation({
    required this.conversation,
  });

  /// Wire snapshot from ActionCable — duplicates [ChatwootConversationDto] cable semantics:
  /// `conversation.messages` has **at most one** entry (latest chat message), never full history.
  final ChatwootConversationDto conversation;
}

class ChatwootSocketEvent$Conversation$StatusChanged extends ChatwootSocketEvent$Conversation {
  const ChatwootSocketEvent$Conversation$StatusChanged({
    required super.conversation,
  });
}

class ChatwootSocketEvent$Conversation$TypingOn extends ChatwootSocketEvent$Conversation {
  const ChatwootSocketEvent$Conversation$TypingOn({
    required super.conversation,
  });
}

class ChatwootSocketEvent$Conversation$TypingOff extends ChatwootSocketEvent$Conversation {
  const ChatwootSocketEvent$Conversation$TypingOff({
    required super.conversation,
  });
}
