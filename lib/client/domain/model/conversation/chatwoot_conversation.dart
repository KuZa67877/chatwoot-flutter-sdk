import 'package:meta/meta.dart';

import '../message/chatwoot_message.dart';

enum ChatwootConversationStatus {
  open,
  resolved,
  pending,
  snoozed,
}

extension type ChatwootConversationId(int value) implements int {}

@immutable
class ChatwootConversation {
  const ChatwootConversation({
    required this.id,
    required this.status,
    this.messages = const [],
    this.supportTyping = false,
  });

  final ChatwootConversationId id;
  final ChatwootConversationStatus status;
  final List<ChatwootMessage> messages;

  /// Support is typing in this conversation.
  final bool supportTyping;

  ChatwootConversation copyWith({
    List<ChatwootMessage>? messages,
    ChatwootConversationStatus? status,
    bool? supportTyping,
    bool? canReply,
  }) {
    return ChatwootConversation(
      id: id,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      supportTyping: supportTyping ?? this.supportTyping,
    );
  }
}
