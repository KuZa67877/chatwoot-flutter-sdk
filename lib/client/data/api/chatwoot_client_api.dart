import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_contact_session_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_contact_session_update_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_dto.dart';
import 'package:cross_file/cross_file.dart';

abstract interface class ChatwootClientApi {
  Future<ChatwootContactSessionDto> createContactSession({
    String? sourceId,
    String? identifier,
    String? identifierHash,
    String? name,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    Map<String, Object?> customAttributes,
  });

  Future<ChatwootContactSessionDto> getContactSession(String contactId);

  Future<ChatwootContactSessionUpdateDto> updateContact(
    String contactId, {
    String? identifier,
    String? identifierHash,
    String? name,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    Map<String, Object?> customAttributes,
  });

  Future<List<ChatwootConversationDto>> listConversations(String contactId);

  Future<ChatwootConversationDto> createConversation(
    String contactId, {
    Map<String, Object?> customAttributes,
  });

  Future<ChatwootConversationDto> getConversation(
    String contactId,
    int conversationId,
  );

  Future<List<ChatwootMessageDto>> listMessages(
    String contactId,
    int conversationId, {
    String? before,
  });

  Future<ChatwootMessageDto> createMessage(
    String contactId,
    int conversationId, {
    String? content,
    String? echoId,
    List<XFile> attachments = const [],
  });

  /// Public Client API: resolves the conversation for the contact (`POST …/toggle_status`).
  Future<void> toggleConversationResolved(
    String contactId,
    int conversationId,
  );

  /// Public Client API: contact typing indicator (`POST …/toggle_typing`).
  Future<void> toggleConversationTyping(
    String contactId,
    int conversationId, {
    required bool isTyping,
  });

  /// Public Client API: mark conversation as seen (`POST …/update_last_seen`).
  Future<void> updateConversationLastSeen(
    String contactId,
    int conversationId,
  );
}
