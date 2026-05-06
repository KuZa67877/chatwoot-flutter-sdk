// import 'dart:async';

// import 'package:chatwoot_sdk/client/data/api/chatwoot_client_api.dart';
// import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_attachment_push_event_dto.dart';
// import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_contact_merged_push_dto.dart';
// import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_dto.dart';
// import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_push_dto.dart';
// import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_dto.dart';
// import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_sender_dto.dart';
// import 'package:chatwoot_sdk/client/data/api/http_chatwoot_client_api.dart';
// import 'package:chatwoot_sdk/client/data/realtime_client/chatwoot_action_cable_client.dart';
// import 'package:chatwoot_sdk/client/data/realtime_client/chatwoot_cable_uri.dart';
// import 'package:chatwoot_sdk/client/data/session_storage/session_storage.dart';
// import 'package:chatwoot_sdk/client/domain/chatwoot_event.dart';
// import 'package:chatwoot_sdk/client/domain/model/attachment.dart';
// import 'package:chatwoot_sdk/client/domain/model/authorization_creds.dart';
// import 'package:chatwoot_sdk/client/domain/model/chatwoot_contact.dart';
// import 'package:chatwoot_sdk/client/domain/model/chatwoot_conversation.dart';
// import 'package:chatwoot_sdk/client/domain/model/chatwoot_message.dart';
// import 'package:chatwoot_sdk/client/domain/model/chatwoot_session.dart';
// import 'package:rxdart/rxdart.dart';
// import 'package:uuid/uuid.dart';

// class ChatwootClient {
//   factory ChatwootClient({
//     required String inboxIdentifier,
//     required SessionStorage sessionStorage,
//     required Uri baseUrl,
//     ChatwootClientApi? api,
//   }) {
//     return ChatwootClient._(
//       api ??
//           HttpChatwootClientApi(
//             baseUrl: baseUrl,
//             inboxIdentifier: inboxIdentifier,
//           ),
//       sessionStorage,
//       Uuid(),
//       baseUrl,
//     );
//   }

//   ChatwootClient._(this.api, this.sessionStorage, this.uuid, this._baseUrl);

//   final ChatwootClientApi api;
//   final SessionStorage sessionStorage;
//   final Uuid uuid;
//   final Uri _baseUrl;

//   ChatwootSession? _session;
//   ChatwootActionCableClient? _cable;
//   bool _disposed = false;

//   ChatwootSession get session {
//     if (_session == null) {
//       throw StateError('Session is not authorized. Please call `authorize` or `init` first.');
//     }

//     return _session!;
//   }

//   final BehaviorSubject<List<ChatwootConversation>> _conversationsSubject = BehaviorSubject.seeded([]);

//   Stream<List<ChatwootConversation>> get conversations => _conversationsSubject.stream;

//   static const Duration _typingAutoOff = Duration(seconds: 30);

//   final Map<int, Timer> _supportTypingTimers = {};

//   Future<void> init({
//     AuthorizationCreds? initialCreds,
//   }) async {
//     if (initialCreds case final creds?) {
//       return authorize(creds: creds);
//     }

//     final activeSession = await sessionStorage.read();

//     if (activeSession != null) {
//       final sessionDto = await api.getContactSession(activeSession);

//       _session = ChatwootSession(
//         sourceId: sessionDto.sourceId,
//         token: sessionDto.pubsubToken,
//         contact: ChatwootContact(
//           id: sessionDto.id,
//           name: sessionDto.name,
//           email: sessionDto.email,
//           phoneNumber: sessionDto.phoneNumber,
//         ),
//       );
//     } else {
//       final sessionDto = await api.createContactSession();

//       _session = ChatwootSession(
//         sourceId: sessionDto.sourceId,
//         token: sessionDto.pubsubToken,
//         contact: ChatwootContact(
//           id: sessionDto.id,
//           name: sessionDto.name,
//           email: sessionDto.email,
//           phoneNumber: sessionDto.phoneNumber,
//         ),
//       );

//       await sessionStorage.save(sessionDto.sourceId);
//     }

//     final conversations = await api.listConversations(_session!.sourceId);

//     _conversationsSubject.add(conversations.map((e) => e.toDomain()).toList());
//     await _connectCable();
//   }

//   bool _closed = false;

//   Future<void> dispose() async {
//     if (_closed) {
//       return;
//     }
//     _closed = true;
//     _disposed = true;
//     await _cable?.dispose();
//     _cable = null;
//     _cancelAllTypingTimers();
//     await _conversationsSubject.close();
//   }

//   Future<void> authorize({
//     required AuthorizationCreds creds,
//   }) async {
//     final sessionDto = await api.createContactSession(
//       identifier: creds.identifier,
//       identifierHash: creds.identifierHash,
//       name: creds.name,
//       email: creds.email,
//       phoneNumber: creds.phoneNumber,
//       customAttributes: creds.customAttributes,
//     );

//     _session = ChatwootSession(
//       sourceId: sessionDto.sourceId,
//       token: sessionDto.pubsubToken,
//       contact: ChatwootContact(
//         id: sessionDto.id,
//         name: sessionDto.name,
//         email: sessionDto.email,
//         phoneNumber: sessionDto.phoneNumber,
//       ),
//     );

//     await sessionStorage.save(sessionDto.sourceId);

//     final conversations = await api.listConversations(_session!.sourceId);

//     _conversationsSubject.add(conversations.map((e) => e.toDomain()).toList());
//     await _connectCable();
//   }

//   /// Reloads all conversations from the Client API (REST).
//   Future<void> refreshConversations() async {
//     final list = await api.listConversations(session.sourceId);
//     _cancelAllTypingTimers();
//     _conversationsSubject.add(list.map((e) => e.toDomain()).toList());
//   }

//   /// Reloads one conversation (including messages) from the Client API.
//   Future<void> refreshConversation(int conversationId) async {
//     final dto = await api.getConversation(session.sourceId, conversationId);
//     final updated = dto.toDomain();
//     final list = [..._conversationsSubject.value];
//     final idx = list.indexWhere((item) => item.id == conversationId);
//     if (idx < 0) {
//       list.add(updated);
//     } else {
//       final prevTyping = list[idx].supportTyping;
//       list[idx] = updated.copyWith(supportTyping: prevTyping);
//     }
//     _conversationsSubject.add(list);
//   }

//   Future<void> updateContact({
//     String? name,
//     String? email,
//     String? phoneNumber,
//     Map<String, Object> customAttributes = const {},
//   }) async {
//     final updatedSession = await api.updateContact(
//       session.sourceId,
//       name: name,
//       email: email,
//       phoneNumber: phoneNumber,
//       customAttributes: customAttributes,
//     );

//     _session = ChatwootSession(
//       sourceId: session.sourceId,
//       token: session.token,
//       contact: ChatwootContact(
//         id: updatedSession.id,
//         name: updatedSession.name,
//         email: updatedSession.email,
//         phoneNumber: updatedSession.phoneNumber,
//       ),
//     );
//   }

//   Future<ChatwootConversation> createConversation({
//     Map<String, Object?> customAttributes = const {},
//   }) async {
//     final dto = await api.createConversation(session.sourceId, customAttributes: customAttributes);
//     final conversation = dto.toDomain();

//     _conversationsSubject.add([
//       ..._conversationsSubject.value,
//       conversation,
//     ]);

//     return conversation;
//   }

//   Future<void> sendMessage({
//     required int conversationId,
//     String? content,
//     List<Attachment$Local> attachments = const [],
//   }) async {
//     assert(content != null || attachments.isNotEmpty, 'Either content or attachments must be provided');

//     final message = ChatwootMessage$Outgoing(
//       id: 0,
//       echoId: uuid.v1(),
//       sentAt: DateTime.now(),
//       content: content,
//       attachments: attachments,
//       status: OutgoingMessageStatus.sending,
//     );

//     final conversations = _conversationsSubject.value;

//     final index = conversations.indexWhere((item) => item.id == conversationId);

//     if (index < 0) {
//       return;
//     }

//     final conversation = conversations[index];
//     final messages = [...conversation.messages, message];
//     final updatedConversation = conversation.copyWith(messages: messages);

//     _conversationsSubject.add(List.from(conversations)..[index] = updatedConversation);

//     final dto = await api.createMessage(
//       session.sourceId,
//       conversationId,
//       content: content,
//       echoId: message.echoId,
//       attachments: attachments,
//     );

//     final createdMessage = dto.toDomain(outgoingStatus: OutgoingMessageStatus.delivered);

//     _applyMessage(conversationId, createdMessage);
//   }

//   Future<void> _connectCable() async {
//     if (_disposed || _session == null) {
//       return;
//     }
//     await _cable?.dispose();
//     _cable = ChatwootActionCableClient(
//       cableUri: chatwootCableUri(_baseUrl),
//       pubsubToken: _session!.token,
//       onEnvelope: _onCableEnvelope,
//       onError: (_, __) {},
//     );
//     _cable!.connect();
//   }

//   void _onCableEnvelope(String event, Map<String, dynamic> data) {
//     if (_disposed) {
//       return;
//     }
//     if (event == 'conversation.typing_on') {
//       if (data['is_private'] == true) {
//         return;
//       }
//       final id = _typingConversationId(data);
//       if (id != null) {
//         _setSupportTyping(id, true);
//       }
//       return;
//     }
//     if (event == 'conversation.typing_off') {
//       final id = _typingConversationId(data);
//       if (id != null) {
//         _setSupportTyping(id, false);
//       }
//       return;
//     }

//     final typed = ChatwootEvent.fromEnvelope(event, data);
//     switch (typed) {
//       case ChatwootMessageCreatedEvent(:final message):
//         _handlePushMessage(message);
//       case ChatwootMessageUpdatedEvent(:final message):
//         _handlePushMessage(message);
//       case ChatwootConversationCreatedEvent(:final conversation):
//         _mergeConversationFromPush(conversation);
//       case ChatwootConversationStatusChangedEvent(:final conversation):
//         _mergeConversationFromPush(conversation);
//       case ChatwootContactMergedEvent(:final merge):
//         unawaited(_handleContactMerged(merge));
//       default:
//         break;
//     }
//   }

//   static int? _typingConversationId(Map<String, dynamic> json) {
//     final conv = json['conversation'];
//     if (conv is! Map) {
//       return null;
//     }
//     final idRaw = conv['id'];
//     return switch (idRaw) {
//       final int i => i,
//       final num n => n.toInt(),
//       _ => null,
//     };
//   }

//   void _cancelTypingTimer(int conversationId) {
//     _supportTypingTimers.remove(conversationId)?.cancel();
//   }

//   void _cancelAllTypingTimers() {
//     for (final t in _supportTypingTimers.values) {
//       t.cancel();
//     }
//     _supportTypingTimers.clear();
//   }

//   void _setSupportTyping(int conversationId, bool typing) {
//     final list = [..._conversationsSubject.value];
//     final idx = list.indexWhere((c) => c.id == conversationId);
//     if (idx < 0) {
//       return;
//     }
//     _cancelTypingTimer(conversationId);
//     if (typing) {
//       _supportTypingTimers[conversationId] = Timer(_typingAutoOff, () {
//         if (_disposed) {
//           return;
//         }
//         _setSupportTyping(conversationId, false);
//       });
//     }
//     list[idx] = list[idx].copyWith(supportTyping: typing);
//     _conversationsSubject.add(list);
//   }

//   void _handlePushMessage(ChatwootMessageDto dto) {
//     if (_messagePushMarksDeleted(dto)) {
//       _removeMessageFromConversation(dto.conversationId, dto.id);
//       return;
//     }
//     final msg = dto.toDomain(outgoingStatus: OutgoingMessageStatus.delivered);
//     unawaited(_upsertMessageForConversation(dto.conversationId, msg));
//   }

//   /// Chatwoot does not emit `message.deleted` on the wire: the agent soft-delete
//   /// is a [message.updated] with `content_attributes.deleted` (see widget
//   /// `addOrUpdateMessage` in Chatwoot v4.8.0).
//   static bool _messagePushMarksDeleted(ChatwootMessageDto dto) {
//     final v = dto.contentAttributes['deleted'];
//     if (v == true || v == 1) {
//       return true;
//     }
//     if (v is String) {
//       final s = v.toLowerCase();
//       return s == 'true' || s == '1';
//     }
//     return false;
//   }

//   void _removeMessageFromConversation(int conversationId, int messageId) {
//     final list = [..._conversationsSubject.value];
//     final idx = list.indexWhere((c) => c.id == conversationId);
//     if (idx < 0) {
//       return;
//     }
//     final conv = list[idx];
//     final messages = conv.messages.where((m) => m.id != messageId).toList();
//     list[idx] = conv.copyWith(messages: messages);
//     _conversationsSubject.add(list);
//   }

//   void _mergeConversationFromPush(ChatwootConversationPushDto push) {
//     final id = push.id;
//     ChatwootConversationStatus? status;
//     final statusRaw = push.status;
//     if (statusRaw != null) {
//       try {
//         status = ChatwootConversationStatus.values.byName(statusRaw);
//       } catch (_) {
//         status = null;
//       }
//     }

//     final list = [..._conversationsSubject.value];
//     final idx = list.indexWhere((c) => c.id == id);

//     if (idx < 0) {
//       var conv = ChatwootConversation(
//         id: id,
//         status: status ?? ChatwootConversationStatus.open,
//         messages: [],
//       );
//       conv = _mergePushMessagesFromDtos(conv, push.messages);
//       list.add(conv);
//       _conversationsSubject.add(list);
//       return;
//     }

//     var conv = list[idx];
//     if (status != null) {
//       conv = conv.copyWith(status: status);
//     }
//     conv = _mergePushMessagesFromDtos(conv, push.messages);
//     list[idx] = conv;
//     _conversationsSubject.add(list);
//   }

//   ChatwootConversation _mergePushMessagesFromDtos(
//     ChatwootConversation conv,
//     List<ChatwootMessageDto> dtos,
//   ) {
//     var next = conv;
//     for (final dto in dtos) {
//       if (_messagePushMarksDeleted(dto)) {
//         next = _removeMessageByIdFromConversation(next, dto.id);
//         continue;
//       }
//       try {
//         final msg = dto.toDomain(outgoingStatus: OutgoingMessageStatus.delivered);
//         next = _mergeMessageIntoConversation(next, msg);
//       } catch (_) {}
//     }
//     return next;
//   }

//   ChatwootConversation _removeMessageByIdFromConversation(ChatwootConversation conv, int messageId) {
//     return conv.copyWith(
//       messages: conv.messages.where((m) => m.id != messageId).toList(),
//     );
//   }

//   Future<void> _upsertMessageForConversation(int conversationId, ChatwootMessage message) async {
//     final list = [..._conversationsSubject.value];
//     final idx = list.indexWhere((c) => c.id == conversationId);
//     if (idx < 0) {
//       try {
//         final dto = await api.getConversation(session.sourceId, conversationId);
//         var conv = dto.toDomain();
//         conv = _mergeMessageIntoConversation(conv, message);
//         list.add(conv);
//         _conversationsSubject.add(list);
//       } catch (_) {}
//       return;
//     }
//     list[idx] = _mergeMessageIntoConversation(list[idx], message);
//     _conversationsSubject.add(list);
//   }

//   ChatwootConversation _mergeMessageIntoConversation(ChatwootConversation conv, ChatwootMessage incoming) {
//     final messages = List<ChatwootMessage>.from(conv.messages);
//     final echoId = incoming.echoId;
//     if (echoId != null && echoId.isNotEmpty) {
//       final optIdx = messages.indexWhere((m) => m.echoId == echoId);
//       if (optIdx >= 0) {
//         messages[optIdx] = incoming;
//         return conv.copyWith(messages: messages);
//       }
//     }
//     if (incoming.id != 0) {
//       final idIdx = messages.indexWhere((m) => m.id == incoming.id);
//       if (idIdx >= 0) {
//         messages[idIdx] = incoming;
//         return conv.copyWith(messages: messages);
//       }
//     }
//     messages.add(incoming);
//     messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
//     return conv.copyWith(messages: messages);
//   }

//   Future<void> _handleContactMerged(ChatwootContactMergedPushDto data) async {
//     final token = data.pubsubToken;
//     if (token != null && token.isNotEmpty && _session != null) {
//       _session = ChatwootSession(
//         sourceId: _session!.sourceId,
//         token: token,
//         contact: _session!.contact,
//       );
//       await _connectCable();
//       return;
//     }
//     try {
//       final s = await api.getContactSession(session.sourceId);
//       _session = ChatwootSession(
//         sourceId: s.sourceId,
//         token: s.pubsubToken,
//         contact: ChatwootContact(
//           id: s.id,
//           name: s.name,
//           email: s.email,
//           phoneNumber: s.phoneNumber,
//         ),
//       );
//       await _connectCable();
//     } catch (_) {}
//   }

//   void _applyMessage(int conversationId, ChatwootMessage message) {
//     final conversations = _conversationsSubject.value;

//     final index = conversations.indexWhere((item) => item.id == conversationId);

//     if (index < 0) {
//       return;
//     }

//     final conversation = conversations[index];
//     final messageIndex = conversation.messages.indexWhere((item) => item.echoId == message.echoId);

//     if (messageIndex < 0) {
//       return;
//     }

//     final updatedMessages = List<ChatwootMessage>.from(conversation.messages)..[messageIndex] = message;
//     final updatedConversation = conversation.copyWith(messages: updatedMessages);

//     _conversationsSubject.add(List.from(conversations)..[index] = updatedConversation);
//   }
// }

// extension on ChatwootConversationDto {
//   ChatwootConversation toDomain() {
//     return ChatwootConversation(
//       id: id,
//       status: ChatwootConversationStatus.values.byName(status),
//       messages: messages.map((e) => e.toDomain(outgoingStatus: OutgoingMessageStatus.delivered)).toList(),
//       supportTyping: false,
//     );
//   }
// }

// extension on ChatwootMessageDto {
//   ChatwootMessage toDomain({
//     required OutgoingMessageStatus outgoingStatus,
//   }) {
//     switch (messageType) {
//       case 0:
//         return ChatwootMessage$Outgoing(
//           id: id,
//           echoId: echoId,
//           sentAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
//           content: content,
//           attachments: attachments.map((e) => e.toDomain()).toList(),
//           status: outgoingStatus,
//         );
//       case 1:
//         return ChatwootMessage$Incoming(
//           id: id,
//           echoId: echoId,
//           sentAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
//           content: content,
//           attachments: attachments.map((e) => e.toDomain()).toList(),
//           sender: sender?.toDomain(),
//         );
//       case 3:
//       default:
//         return ChatwootMessage$Activity(
//           id: id,
//           echoId: echoId,
//           sentAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
//           content: content,
//           attachments: attachments.map((e) => e.toDomain()).toList(),
//         );
//     }
//   }
// }

// extension on ChatwootAttachmentPushEventDto {
//   Attachment toDomain() {
//     return Attachment$Remote(
//       url: Uri.parse(dataUrl!),
//       thumbnail: thumbUrl != null ? Uri.parse(thumbUrl!) : null,
//     );
//   }
// }

// extension on ChatwootPublicMessageSenderDto {
//   ChatwootMessageSender toDomain() {
//     return ChatwootMessageSender(
//       id: id,
//       name: name,
//       avatarUrl: avatarUrl != null ? Uri.parse(avatarUrl!) : null,
//       thumbnail: thumbnail != null ? Uri.parse(thumbnail!) : null,
//     );
//   }
// }
