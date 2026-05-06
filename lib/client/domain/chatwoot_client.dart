import 'package:chatwoot_sdk/client/domain/model/chatwoot_connection_state.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_event.dart';
import 'package:chatwoot_sdk/client/domain/model/conversation/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/client/domain/model/message/attachment.dart';
import 'package:chatwoot_sdk/client/domain/model/message/chatwoot_message.dart';
import 'package:chatwoot_sdk/client/domain/model/session/authorization_creds.dart';

abstract interface class ChatwootClient {
  Future<void> authorize(AuthorizationCreds creds);

  Future<void> bootstrap({
    AuthorizationCreds? defaultCreds,
  });

  Stream<ChatwootEvent> get events;

  Stream<ChatwootConnectionState> get connectionState;

  Stream<List<ChatwootConversation>> get conversations;

  Future<ChatwootConversation> createConversation();

  Future<void> resolveConversation({
    required ChatwootConversationId id,
  });

  Future<void> toggleTyping({
    required ChatwootConversationId conversationId,
    required bool isTyping,
  });

  Future<void> sendMessage({
    required ChatwootConversationId conversationId,
    String? content,
    List<Attachment$File> attachments = const [],
  });

  Future<void> retryMessage({
    required ChatwootConversationId conversationId,
    required ChatwootMessage$Content$Outgoing message,
  });

  Future<void> dispose();
}

