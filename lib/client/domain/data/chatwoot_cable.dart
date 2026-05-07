import 'package:chatwoot_sdk/client/domain/model/chatwoot_connection_state.dart';
import 'package:chatwoot_sdk/client/domain/model/conversation/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/client/domain/model/message/chatwoot_message.dart';

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
    required this.conversationId,
    required this.message,
  });

  final ChatwootConversationId conversationId;
  final ChatwootMessage message;
}

class ChatwootCableEvent$Message$Created extends ChatwootCableEvent$Message {
  const ChatwootCableEvent$Message$Created({
    required super.conversationId,
    required super.message,
  });
}

class ChatwootCableEvent$Message$Updated extends ChatwootCableEvent$Message {
  const ChatwootCableEvent$Message$Updated({
    required super.conversationId,
    required super.message,
  });
}

class ChatwootCableEvent$ConversationStatusChanged extends ChatwootCableEvent {
  const ChatwootCableEvent$ConversationStatusChanged({
    required this.conversation,
  });

  /// When sourced from ActionCable, [conversation.messages] is typically **only the latest chat message** (or empty),
  /// not the full transcript — same semantics as [ChatwootConversationDto] cable payloads.
  final ChatwootConversation conversation;
}

class ChatwootCableEvent$TypingOn extends ChatwootCableEvent {
  const ChatwootCableEvent$TypingOn({
    required this.conversationId,
  });

  final ChatwootConversationId conversationId;
}

class ChatwootCableEvent$TypingOff extends ChatwootCableEvent {
  const ChatwootCableEvent$TypingOff({
    required this.conversationId,
  });

  final ChatwootConversationId conversationId;
}
