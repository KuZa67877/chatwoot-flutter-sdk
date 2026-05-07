import 'package:chatwoot_sdk/client/domain/model/chatwoot_connection_state.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_event.dart';
import 'package:chatwoot_sdk/client/domain/model/conversation/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/client/domain/model/message/chatwoot_message.dart';
import 'package:chatwoot_sdk/client/domain/model/session/authorization_creds.dart';
import 'package:chatwoot_sdk/client/domain/model/session/chatwoot_contact.dart';
import 'package:cross_file/cross_file.dart';

abstract interface class ChatwootClient {
  Future<void> authorize(AuthorizationCreds creds);

  Future<void> bootstrap({
    AuthorizationCreds? defaultCreds,
  });

  Future<void> logout();

  /// Reload conversations from the API (same snapshot as after bootstrap).
  Future<void> refreshConversations();

  Future<void> updateContact({
    String? name,
    String? email,
    String? phoneNumber,
    Map<String, Object?> customAttributes = const {},
  });

  ChatwootContact get contact;

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
    List<XFile> attachments = const [],
  });

  Future<void> retryMessage({
    required ChatwootConversationId conversationId,
    required ChatwootMessage$Content$Outgoing message,
  });

  Future<void> dispose();
}
