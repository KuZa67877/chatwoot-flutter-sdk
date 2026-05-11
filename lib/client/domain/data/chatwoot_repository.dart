import 'package:chatwoot_sdk/client/domain/model/conversation/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/client/domain/model/message/chatwoot_message.dart';
import 'package:chatwoot_sdk/client/domain/model/session/authorization_creds.dart';
import 'package:chatwoot_sdk/client/domain/model/session/chatwoot_contact.dart';
import 'package:chatwoot_sdk/client/domain/model/session/chatwoot_session.dart';
import 'package:cross_file/cross_file.dart';

abstract interface class ChatwootRepository {
  Future<ChatwootSession> authorize(AuthorizationCreds creds);

  Future<ChatwootContact> updateContact({
    required String sourceId,
    required String? identifier,
    String? name,
    String? email,
    String? phoneNumber,
    Map<String, Object?> customAttributes = const {},
  });

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
    List<XFile> attachments = const [],
  });

  Future<void> retryMessage({
    required String sourceId,
    required ChatwootConversationId conversationId,
    required ChatwootMessage$Content$Outgoing message,
  });

  Future<void> markPresence({
    required String sourceId,
  });

  Future<void> markConversationRead({
    required String sourceId,
    required ChatwootConversationId conversationId,
  });

  Future<void> toggleTyping({
    required String sourceId,
    required ChatwootConversationId conversationId,
    required bool isTyping,
  });
}
