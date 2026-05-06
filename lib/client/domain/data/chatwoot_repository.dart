import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/client/domain/model/message/attachment.dart';
import 'package:chatwoot_sdk/client/domain/model/session/authorization_creds.dart';

abstract interface class ChatwootRepository {
  Future<ChatwootSession> authorize(AuthorizationCreds creds);

  Future<ChatwootSession?> currentSession();

  Future<List<ChatwootConversation>> fetchConversations({
    required String sourceId,
  });

  Future<ChatwootConversation> createConversation({
    required String sourceId,
    Map<String, Object?> customAttributes = const {},
  });

  Future<ChatwootConversation> resolveConversation({
    required String sourceId,
    required ChatwootConversationId conversationId,
  });

  Future<void> sendMessage({
    required String sourceId,
    required ChatwootConversationId conversationId,
    String? content,
    List<Attachment$File> attachments = const [],
  });

  Future<void> retryMessage({
    required String sourceId,
    required ChatwootConversationId conversationId,
    required ChatwootMessage$Content$Outgoing message,
  });

  Future<void> markPresence({
    required String sourceId,
  });

  Future<void> toggleTyping({
    required String sourceId,
    required ChatwootConversationId conversationId,
    required bool isTyping,
  });
}
