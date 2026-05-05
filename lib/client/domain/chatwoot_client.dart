import 'package:chatwoot_sdk/client/data/api/chatwoot_client_api.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_attachment_push_event_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_sender_dto.dart';
import 'package:chatwoot_sdk/client/data/api/http_chatwoot_client_api.dart';
import 'package:chatwoot_sdk/client/data/session_storage/session_storage.dart';
import 'package:chatwoot_sdk/client/domain/model/attachment.dart';
import 'package:chatwoot_sdk/client/domain/model/authorization_creds.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_contact.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_message.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

class ChatwootClient {
  factory ChatwootClient({
    required String inboxIdentifier,
    required SessionStorage sessionStorage,
    required Uri baseUrl,
    ChatwootClientApi? api,
  }) {
    return ChatwootClient._(
      api ??
          HttpChatwootClientApi(
            baseUrl: baseUrl,
            inboxIdentifier: inboxIdentifier,
          ),
      sessionStorage,
      Uuid(),
    );
  }

  ChatwootClient._(this.api, this.sessionStorage, this.uuid);

  final ChatwootClientApi api;
  final SessionStorage sessionStorage;
  final Uuid uuid;

  ChatwootSession? _session;

  ChatwootSession get session {
    if (_session == null) {
      throw StateError('Session is not authorized. Please call `authorize` or `init` first.');
    }

    return _session!;
  }

  final BehaviorSubject<List<ChatwootConversation>> _conversationsSubject = BehaviorSubject.seeded([]);

  Stream<List<ChatwootConversation>> get conversations => _conversationsSubject.stream;

  Future<void> init({
    AuthorizationCreds? initialCreds,
  }) async {
    if (initialCreds case final creds?) {
      return authorize(creds: creds);
    }

    final activeSession = await sessionStorage.read();

    if (activeSession != null) {
      final session = await api.getContactSession(activeSession);

      _session = ChatwootSession(
        sourceId: session.sourceId,
        pubsubToken: session.pubsubToken,
        contact: ChatwootContact(
          id: session.id,
          name: session.name,
          email: session.email,
          phoneNumber: session.phoneNumber,
        ),
      );
    } else {
      final session = await api.createContactSession();

      _session = ChatwootSession(
        sourceId: session.sourceId,
        pubsubToken: session.pubsubToken,
        contact: ChatwootContact(
          id: session.id,
          name: session.name,
          email: session.email,
          phoneNumber: session.phoneNumber,
        ),
      );

      await sessionStorage.save(session.sourceId);
    }

    final conversations = await api.listConversations(session.sourceId);

    _conversationsSubject.add(conversations.map((e) => e.toDomain()).toList());
  }

  Future<void> dispose() async {
    _conversationsSubject.close();
  }

  Future<void> authorize({
    required AuthorizationCreds creds,
  }) async {
    final session = await api.createContactSession(
      identifier: creds.identifier,
      identifierHash: creds.identifierHash,
      name: creds.name,
      email: creds.email,
      phoneNumber: creds.phoneNumber,
      customAttributes: creds.customAttributes,
    );

    _session = ChatwootSession(
      sourceId: session.sourceId,
      pubsubToken: session.pubsubToken,
      contact: ChatwootContact(
        id: session.id,
        name: session.name,
        email: session.email,
        phoneNumber: session.phoneNumber,
      ),
    );

    final conversations = await api.listConversations(session.sourceId);

    _conversationsSubject.add(conversations.map((e) => e.toDomain()).toList());
  }

  Future<void> updateContact({
    String? name,
    String? email,
    String? phoneNumber,
    Map<String, Object> customAttributes = const {},
  }) async {
    final updatedSession = await api.updateContact(
      session.sourceId,
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      customAttributes: customAttributes,
    );

    _session = ChatwootSession(
      sourceId: session.sourceId,
      pubsubToken: session.pubsubToken,
      contact: ChatwootContact(
        id: updatedSession.id,
        name: updatedSession.name,
        email: updatedSession.email,
        phoneNumber: updatedSession.phoneNumber,
      ),
    );
  }

  Future<ChatwootConversation> createConversation({
    Map<String, Object?> customAttributes = const {},
  }) async {
    final dto = await api.createConversation(session.sourceId, customAttributes: customAttributes);
    final conversation = dto.toDomain();

    _conversationsSubject.add([
      ..._conversationsSubject.value,
      conversation,
    ]);

    return conversation;
  }

  Future<void> sendMessage({
    required int conversationId,
    String? content,
    List<Attachment$Local> attachments = const [],
  }) async {
    assert(content != null || attachments.isNotEmpty, 'Either content or attachments must be provided');

    final message = ChatwootMessage$Outgoing(
      id: 0,
      echoId: uuid.v1(),
      sentAt: DateTime.now(),
      content: content,
      attachments: attachments,
      status: OutgoingMessageStatus.sending,
    );

    final conversations = _conversationsSubject.value;

    final index = conversations.indexWhere((item) => item.id == conversationId);

    if (index < 0) {
      return;
    }

    final conversation = conversations[index];
    final messages = [...conversation.messages, message];
    final updatedConversation = conversation.copyWith(messages: messages);

    _conversationsSubject.add(List.from(conversations)..[index] = updatedConversation);

    final dto = await api.createMessage(
      session.sourceId,
      conversationId,
      content: content,
      echoId: message.echoId,
      attachments: attachments,
    );

    final createdMessage = dto.toDomain(outgoingStatus: OutgoingMessageStatus.delivered);

    _applyMessage(conversationId, createdMessage);
  }

  void _applyMessage(int conversationId, ChatwootMessage message) {
    final conversations = _conversationsSubject.value;

    final index = conversations.indexWhere((item) => item.id == conversationId);

    final conversation = conversations[index];
    final messageIndex = conversation.messages.indexWhere((item) => item.echoId == message.echoId);

    if (messageIndex < 0) {
      return;
    }

    final updatedMessages = List<ChatwootMessage>.from(conversation.messages)..[messageIndex] = message;
    final updatedConversation = conversation.copyWith(messages: updatedMessages);

    _conversationsSubject.add(List.from(conversations)..[index] = updatedConversation);
  }
}

extension on ChatwootConversationDto {
  ChatwootConversation toDomain() {
    return ChatwootConversation(
      id: id,
      status: ChatwootConversationStatus.values.byName(status),
      messages: messages.map((e) => e.toDomain(outgoingStatus: OutgoingMessageStatus.delivered)).toList(),
    );
  }
}

extension on ChatwootMessageDto {
  ChatwootMessage toDomain({
    required OutgoingMessageStatus outgoingStatus,
  }) {
    switch (messageType) {
      case 0:
        return ChatwootMessage$Outgoing(
          id: id,
          echoId: echoId,
          sentAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
          content: content,
          attachments: attachments.map((e) => e.toDomain()).toList(),
          status: outgoingStatus,
        );
      case 1:
        return ChatwootMessage$Incoming(
          id: id,
          echoId: echoId,
          sentAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
          content: content,
          attachments: attachments.map((e) => e.toDomain()).toList(),
          sender: sender?.toDomain(),
        );
      case 3:
      default:
        return ChatwootMessage$Activity(
          id: id,
          echoId: echoId,
          sentAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
          content: content,
          attachments: attachments.map((e) => e.toDomain()).toList(),
        );
    }
  }
}

extension on ChatwootAttachmentPushEventDto {
  Attachment toDomain() {
    return Attachment$Remote(
      url: Uri.parse(dataUrl!),
      thumbnail: thumbUrl != null ? Uri.parse(thumbUrl!) : null,
    );
  }
}

extension on ChatwootPublicMessageSenderDto {
  ChatwootMessageSender toDomain() {
    return ChatwootMessageSender(
      id: id,
      name: name,
      avatarUrl: avatarUrl != null ? Uri.parse(avatarUrl!) : null,
      thumbnail: thumbnail != null ? Uri.parse(thumbnail!) : null,
    );
  }
}
