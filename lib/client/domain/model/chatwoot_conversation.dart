import 'package:meta/meta.dart';

import 'chatwoot_message.dart';

enum ChatwootConversationStatus {
  open,
  resolved,
  pending,
  snoozed,
}

@immutable
class ChatwootConversation {
  const ChatwootConversation({
    required this.id,
    required this.status,
    this.messages = const [],
    this.supportTyping = false,
  });

  final int id;
  final ChatwootConversationStatus status;
  final List<ChatwootMessage> messages;

  /// Саппорт печатает в этом диалоге (ActionCable `conversation.typing_on` / off, клиентский таймаут).
  final bool supportTyping;

  ChatwootConversation copyWith({
    List<ChatwootMessage>? messages,
    ChatwootConversationStatus? status,
    bool? supportTyping,
  }) {
    return ChatwootConversation(
      id: id,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      supportTyping: supportTyping ?? this.supportTyping,
    );
  }
}
