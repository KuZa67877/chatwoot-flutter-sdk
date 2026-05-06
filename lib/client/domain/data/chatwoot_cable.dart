import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_dto.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_connection_state.dart';

abstract interface class ChatwootCable {
  Stream<ChatwootConnectionState> get connectionState;

  Stream<ChatwootCableEvent> get events;

  Future<void> connect({
    required String sourceId,
    required String pubsubToken,
  });

  Future<void> disconnect();
}

sealed class ChatwootCableEvent {
  const ChatwootCableEvent();
}

sealed class ChatwootCableEvent$Message extends ChatwootCableEvent {
  const ChatwootCableEvent$Message({
    required this.message,
  });

  final ChatwootMessageDto message;
}

class ChatwootCableEvent$Message$Created extends ChatwootCableEvent$Message {
  const ChatwootCableEvent$Message$Created({
    required super.message,
  });
}

class ChatwootCableEvent$Message$Updated extends ChatwootCableEvent$Message {
  const ChatwootCableEvent$Message$Updated({
    required super.message,
  });
}

sealed class ChatwootCableEvent$Conversation extends ChatwootCableEvent {
  const ChatwootCableEvent$Conversation({
    required this.conversation,
  });

  /// ActionCable sends only the latest chat message in `messages`, not the full history.
  final ChatwootConversationDto conversation;
}

class ChatwootCableEvent$Conversation$StatusChanged extends ChatwootCableEvent$Conversation {
  const ChatwootCableEvent$Conversation$StatusChanged({
    required super.conversation,
  });
}

class ChatwootCableEvent$Conversation$TypingOn extends ChatwootCableEvent$Conversation {
  const ChatwootCableEvent$Conversation$TypingOn({
    required super.conversation,
  });
}

class ChatwootCableEvent$Conversation$TypingOff extends ChatwootCableEvent$Conversation {
  const ChatwootCableEvent$Conversation$TypingOff({
    required super.conversation,
  });
}
