import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_contact_session_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_contact_session_update_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_dto.dart';
import 'package:chatwoot_sdk/client/domain/model/message/attachment.dart';

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
    List<Attachment$File> attachments = const [],
  });
}
