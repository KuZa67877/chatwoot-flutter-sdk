import 'dart:convert';

import 'package:chatwoot_sdk/client/data/api/chatwoot_api_exception.dart';
import 'package:chatwoot_sdk/client/data/api/chatwoot_client_api.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_contact_session_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_contact_session_update_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_dto.dart';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class HttpChatwootClientApi implements ChatwootClientApi {
  HttpChatwootClientApi({
    required Uri baseUrl,
    required String inboxIdentifier,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client(),
       _apiRoot = baseUrl.replace(
         path: '/public/api/v1/',
       ),
       _inboxIdentifier = inboxIdentifier;

  final http.Client _client;
  final Uri _apiRoot;
  final String _inboxIdentifier;

  Uri _resolve(String relativePath) {
    final rel = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    return _apiRoot.resolve(rel);
  }

  Uri _contactsCollection() => _resolve('inboxes/${Uri.encodeComponent(_inboxIdentifier)}/contacts');

  Uri _contactMember(String contactId) => _resolve(
    'inboxes/${Uri.encodeComponent(_inboxIdentifier)}/contacts/${Uri.encodeComponent(contactId)}',
  );

  Uri _conversationsCollection(String contactId) => _resolve(
    'inboxes/${Uri.encodeComponent(_inboxIdentifier)}/contacts/${Uri.encodeComponent(contactId)}/conversations',
  );

  Uri _conversationMember(String contactId, int conversationId) => _resolve(
    'inboxes/${Uri.encodeComponent(_inboxIdentifier)}/contacts/${Uri.encodeComponent(contactId)}/conversations/$conversationId',
  );

  Uri _conversationMemberAction(String contactId, int conversationId, String action) {
    final base = _conversationMember(contactId, conversationId);
    return base.replace(path: '${base.path}/$action');
  }

  Uri _messagesCollection(String contactId, int conversationId, {String? before}) {
    final base = _resolve(
      'inboxes/${Uri.encodeComponent(_inboxIdentifier)}/contacts/${Uri.encodeComponent(contactId)}/conversations/$conversationId/messages',
    );
    if (before == null || before.isEmpty) return base;
    return base.replace(queryParameters: {'before': before});
  }

  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  void _ensureSuccess(http.Response response) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) return;
    throw ChatwootApiException(code, utf8.decode(response.bodyBytes));
  }

  Object? _decodeJson(http.Response response) {
    _ensureSuccess(response);
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /* #region Contact session */
  @override
  Future<ChatwootContactSessionDto> getContactSession(String contactId) async {
    final response = await _client.get(_contactMember(contactId), headers: _jsonHeaders);
    final data = _decodeJson(response);
    return ChatwootContactSessionDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<ChatwootContactSessionDto> createContactSession({
    String? sourceId,
    String? identifier,
    String? identifierHash,
    String? name,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    Map<String, Object?> customAttributes = const {},
  }) async {
    final body = <String, dynamic>{
      'source_id': ?sourceId,
      'identifier': ?identifier,
      'identifier_hash': ?identifierHash,
      'name': ?name,
      'email': ?email,
      'phone_number': ?phoneNumber,
      'avatar_url': ?avatarUrl,
      if (customAttributes.isNotEmpty) 'custom_attributes': customAttributes,
    };

    final response = await _client.post(
      _contactsCollection(),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    final data = _decodeJson(response);
    return ChatwootContactSessionDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<ChatwootContactSessionUpdateDto> updateContact(
    String contactId, {
    String? identifier,
    String? identifierHash,
    String? name,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    Map<String, Object?> customAttributes = const {},
  }) async {
    final body = <String, dynamic>{
      'identifier': ?identifier,
      'identifier_hash': ?identifierHash,
      'name': ?name,
      'email': ?email,
      'phone_number': ?phoneNumber,
      'avatar_url': ?avatarUrl,
      if (customAttributes.isNotEmpty) 'custom_attributes': customAttributes,
    };

    final response = await _client.patch(
      _contactMember(contactId),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    _ensureSuccess(response);

    final data = _decodeJson(response);
    return ChatwootContactSessionUpdateDto.fromJson(Map<String, dynamic>.from(data as Map));
  }
  /* #endregion */

  /* #region Conversation */
  @override
  Future<ChatwootConversationDto> createConversation(
    String contactId, {
    Map<String, Object?> customAttributes = const {},
  }) async {
    final body = <String, dynamic>{
      if (customAttributes.isNotEmpty) 'custom_attributes': customAttributes,
    };
    final response = await _client.post(
      _conversationsCollection(contactId),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    final data = _decodeJson(response);
    return ChatwootConversationDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<ChatwootConversationDto> getConversation(String contactId, int conversationId) async {
    final response = await _client.get(
      _conversationMember(contactId, conversationId),
      headers: _jsonHeaders,
    );
    final data = _decodeJson(response);
    return ChatwootConversationDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<ChatwootConversationDto>> listConversations(String contactId) async {
    final response = await _client.get(
      _conversationsCollection(contactId),
      headers: _jsonHeaders,
    );
    final data = _decodeJson(response);
    final list = data as List<dynamic>;
    return list.map((e) => ChatwootConversationDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
  /* #endregion */

  /* #region Message */
  @override
  Future<ChatwootMessageDto> createMessage(
    String contactId,
    int conversationId, {
    String? content,
    String? echoId,
    List<XFile> attachments = const [],
  }) async {
    final uri = _messagesCollection(contactId, conversationId);

    if (attachments.isEmpty) {
      final body = <String, dynamic>{
        'content': ?content,
        'echo_id': ?echoId,
      };
      final response = await _client.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      final data = _decodeJson(response);
      return ChatwootMessageDto.fromJson(Map<String, dynamic>.from(data as Map));
    }

    final request = http.MultipartRequest('POST', uri)
      ..fields.addAll(<String, String>{
        'content': ?content,
        'echo_id': ?echoId,
      });

    for (final file in attachments) {
      final MediaType? ct;

      if (file.mimeType case final mimeType?) {
        ct = MediaType.parse(mimeType);
      } else {
        ct = null;
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachments[]',
          await file.readAsBytes(),
          filename: file.name,
          contentType: ct,
        ),
      );
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = _decodeJson(response);
    return ChatwootMessageDto.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<ChatwootMessageDto>> listMessages(
    String contactId,
    int conversationId, {
    String? before,
  }) async {
    final response = await _client.get(
      _messagesCollection(contactId, conversationId, before: before),
      headers: _jsonHeaders,
    );
    final data = _decodeJson(response);
    final list = data as List<dynamic>;
    return list.map((e) => ChatwootMessageDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<void> toggleConversationResolved(String contactId, int conversationId) async {
    final response = await _client.post(
      _conversationMemberAction(contactId, conversationId, 'toggle_status'),
      headers: _jsonHeaders,
    );
    _ensureSuccess(response);
  }

  @override
  Future<void> toggleConversationTyping(
    String contactId,
    int conversationId, {
    required bool isTyping,
  }) async {
    final response = await _client.post(
      _conversationMemberAction(contactId, conversationId, 'toggle_typing'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{
        'typing_status': isTyping ? 'on' : 'off',
      }),
    );
    _ensureSuccess(response);
  }

  @override
  Future<void> updateConversationLastSeen(String contactId, int conversationId) async {
    final response = await _client.post(
      _conversationMemberAction(contactId, conversationId, 'update_last_seen'),
      headers: _jsonHeaders,
    );
    _ensureSuccess(response);
  }

  /* #endregion */
}
