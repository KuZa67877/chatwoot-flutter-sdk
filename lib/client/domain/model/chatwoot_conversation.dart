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
  });

  final int id;
  final ChatwootConversationStatus status;
  final List<ChatwootMessage> messages;

  ChatwootConversation copyWith({
    List<ChatwootMessage>? messages,
    ChatwootConversationStatus? status,
  }) {
    return ChatwootConversation(
      id: id,
      status: status ?? this.status,
      messages: messages ?? this.messages,
    );
  }
}
