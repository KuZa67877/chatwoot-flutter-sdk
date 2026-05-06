import 'package:chatwoot_sdk/client/domain/model/conversation/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/client/domain/model/message/chatwoot_message.dart';

sealed class ChatwootEvent {
  const ChatwootEvent();
}

class ChatwootEvent$NewMessage extends ChatwootEvent {
  const ChatwootEvent$NewMessage({
    required this.message,
  });

  final ChatwootMessage message;
}

class ChatwootEvent$ConversationStatusChanged extends ChatwootEvent {
  const ChatwootEvent$ConversationStatusChanged({
    required this.conversation,
  });

  final ChatwootConversation conversation;
}
