import 'dart:async';

import 'package:chatwoot_sdk/client/data/api/http_chatwoot_client_api.dart';
import 'package:chatwoot_sdk/client/data/realtime_client/chatwoot_socket_impl.dart';
import 'package:chatwoot_sdk/client/data/realtime_client/chatwoot_socket_retry_policy.dart';
import 'package:chatwoot_sdk/client/data/session_storage/session_storage.dart';
import 'package:chatwoot_sdk/client/domain/chatwoot_client.dart';
import 'package:chatwoot_sdk/client/domain/chatwoot_realtime_repository.dart';
import 'package:chatwoot_sdk/client/domain/data/chatwoot_cable.dart';
import 'package:chatwoot_sdk/client/domain/data/chatwoot_repository.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_connection_state.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_event.dart';
import 'package:chatwoot_sdk/client/domain/model/conversation/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/client/domain/model/message/chatwoot_message.dart';
import 'package:chatwoot_sdk/client/domain/model/session/authorization_creds.dart';
import 'package:chatwoot_sdk/client/domain/model/session/chatwoot_contact.dart';
import 'package:chatwoot_sdk/client/domain/model/session/chatwoot_session.dart';
import 'package:cross_file/cross_file.dart';
import 'package:rxdart/rxdart.dart';

/// Stateful facade over [`ChatwootRepository`] + [`ChatwootCable`].
class ChatwootClientImpl implements ChatwootClient {
  ChatwootClientImpl({
    required ChatwootRepository repository,
    required ChatwootCable cable,
  }) : _repository = repository,
       _cable = cable;

  /// Wires HTTP API, socket and [`ChatwootRealtimeRepository`] from inbox settings.
  factory ChatwootClientImpl.withHttpSocket({
    required Uri baseUrl,
    required String inboxIdentifier,
    required SessionStorage sessionStorage,
    ChatwootSocketRetryPolicy? retryPolicy,
  }) {
    final api = HttpChatwootClientApi(
      baseUrl: baseUrl,
      inboxIdentifier: inboxIdentifier,
    );
    final socket = ChatwootSocketImpl(
      baseUrl: baseUrl,
      retryPolicy: retryPolicy,
    );
    final gateway = ChatwootRealtimeRepository(
      socket: socket,
      api: api,
      sessionStorage: sessionStorage,
    );
    return ChatwootClientImpl(repository: gateway, cable: gateway);
  }

  final ChatwootRepository _repository;
  final ChatwootCable _cable;

  AuthorizationCreds? _defaultCreds;
  ChatwootSession? _session;
  bool _hasBootstrapped = false;

  StreamSubscription<ChatwootCableEvent>? _cableSub;
  Timer? _presenceTimer;
  bool _disposed = false;

  final BehaviorSubject<List<ChatwootConversation>> _conversations = BehaviorSubject<List<ChatwootConversation>>.seeded(
    const [],
  );

  final PublishSubject<ChatwootEvent> _events = PublishSubject<ChatwootEvent>();

  static AuthorizationCreds _anonymousCreds() => const AuthorizationCreds(
    identifier: null,
    identifierHash: null,
    name: null,
    email: null,
    phoneNumber: null,
    customAttributes: {},
  );

  ChatwootSession get _requireSession {
    if (_disposed) {
      throw StateError('ChatwootClient.dispose() was called.');
    }
    if (!_hasBootstrapped) {
      throw StateError(
        'ChatwootClient.bootstrap() must be called before using ChatwootClient methods.',
      );
    }
    final s = _session;
    if (s == null) {
      throw StateError('ChatwootClient has no active session.');
    }
    return s;
  }

  Future<void> _stopCableAndPresence() async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    await _cableSub?.cancel();
    _cableSub = null;
  }

  void _startPresence() {
    _presenceTimer?.cancel();
    final sid = _session?.id.value;
    if (sid == null) {
      return;
    }
    unawaited(
      _repository.markPresence(sourceId: sid).catchError((Object _) {}),
    );
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_disposed) {
        return;
      }
      if (_session case final session?) {
        unawaited(_repository.markPresence(sourceId: session.id).catchError((Object _) {}));
      }
    });
  }

  Future<void> _attachSession(ChatwootSession session) async {
    _session = session;
    await _cable.connect(
      sourceId: session.id.value,
      pubsubToken: session.token,
    );
    final list = await _repository.fetchConversations(sourceId: session.id.value);
    _conversations.add(list);
    await _cableSub?.cancel();
    _cableSub = _cable.events.listen(
      _onCableEvent,
      onError: _events.addError,
    );
    _startPresence();
  }

  void _onCableEvent(ChatwootCableEvent event) {
    switch (event) {
      case ChatwootCableEvent$Message$Created(:final conversationId, :final message):
        _applyMessage(conversationId, message, emitNewMessageEvent: true);
      case ChatwootCableEvent$Message$Updated(:final conversationId, :final message):
        _applyMessage(conversationId, message, emitNewMessageEvent: false);
      case ChatwootCableEvent$ConversationStatusChanged(:final conversation):
        final list = List<ChatwootConversation>.from(_conversations.value);
        final i = list.indexWhere((c) => c.id == conversation.id);
        late ChatwootConversation updated;
        if (i < 0) {
          updated = conversation;
          list.add(updated);
        } else {
          updated = _mergeConversationPatch(list[i], conversation);
          list[i] = updated;
        }
        _conversations.add(list);
        _events.add(ChatwootEvent$ConversationStatusChanged(conversation: updated));
      case ChatwootCableEvent$TypingOn(:final conversationId):
        _applyTyping(conversationId, true);
      case ChatwootCableEvent$TypingOff(:final conversationId):
        _applyTyping(conversationId, false);
    }
  }

  void _applyTyping(ChatwootConversationId conversationId, bool typing) {
    final list = List<ChatwootConversation>.from(_conversations.value);
    final i = list.indexWhere((c) => c.id == conversationId);
    if (i < 0) {
      return;
    }
    list[i] = list[i].copyWith(supportTyping: typing);
    _conversations.add(list);
  }

  void _applyMessage(
    ChatwootConversationId conversationId,
    ChatwootMessage message, {
    required bool emitNewMessageEvent,
  }) {
    final list = List<ChatwootConversation>.from(_conversations.value);
    final i = list.indexWhere((c) => c.id == conversationId);
    if (i < 0) {
      list.add(
        ChatwootConversation(
          id: conversationId,
          status: ChatwootConversationStatus.open,
          messages: [message],
          supportTyping: false,
        ),
      );
    } else {
      final c = list[i];
      list[i] = c.copyWith(messages: _upsertMessage(c.messages, message));
    }
    _conversations.add(list);
    if (emitNewMessageEvent) {
      _events.add(ChatwootEvent$NewMessage(message: message));
    }
  }

  ChatwootConversation _mergeConversationPatch(
    ChatwootConversation existing,
    ChatwootConversation patch,
  ) {
    var msgs = existing.messages;
    for (final m in patch.messages) {
      msgs = _upsertMessage(msgs, m);
    }
    return existing.copyWith(
      status: patch.status,
      supportTyping: patch.supportTyping,
      messages: msgs,
    );
  }

  List<ChatwootMessage> _upsertMessage(List<ChatwootMessage> messages, ChatwootMessage incoming) {
    final idx = messages.indexWhere((m) => m.isSame(incoming));
    if (idx >= 0) {
      final copy = List<ChatwootMessage>.from(messages);
      copy[idx] = incoming;
      return copy;
    }
    return [...messages, incoming];
  }

  @override
  Future<void> bootstrap({
    AuthorizationCreds? defaultCreds,
  }) async {
    if (_disposed) {
      throw StateError('ChatwootClient.dispose() was called.');
    }
    await _stopCableAndPresence();
    await _cable.disconnect();

    _defaultCreds = defaultCreds;

    ChatwootSession? session = await _repository.currentSession();
    session ??= await _repository.authorize(defaultCreds ?? _anonymousCreds());

    await _attachSession(session);
    _hasBootstrapped = true;
  }

  @override
  Future<void> authorize(AuthorizationCreds creds) async {
    _requireSession;
    await _stopCableAndPresence();
    await _cable.disconnect();
    final session = await _repository.authorize(creds);
    await _attachSession(session);
  }

  @override
  Future<void> logout() async {
    _requireSession;
    await _stopCableAndPresence();
    await _cable.disconnect();
    final session = await _repository.authorize(_defaultCreds ?? _anonymousCreds());
    await _attachSession(session);
  }

  @override
  Future<void> refreshConversations() async {
    final id = _requireSession.id.value;
    final list = await _repository.fetchConversations(sourceId: id);
    _conversations.add(list);
  }

  @override
  Future<void> updateContact({
    String? name,
    String? email,
    String? phoneNumber,
    Map<String, Object?> customAttributes = const {},
  }) async {
    final updatedContact = await _repository.updateContact(
      sourceId: _requireSession.id.value,
      identifier: _requireSession.contact.identifier,
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      customAttributes: customAttributes,
    );

    _session = _requireSession.copyWith(
      contact: updatedContact,
    );
  }

  @override
  ChatwootContact get contact => _requireSession.contact;

  @override
  Stream<ChatwootEvent> get events => _events.stream;

  @override
  Stream<ChatwootConnectionState> get connectionState => _cable.connectionState;

  @override
  Stream<List<ChatwootConversation>> get conversations => _conversations.stream;

  @override
  Future<ChatwootConversation> createConversation() async {
    final created = await _repository.createConversation(sourceId: _requireSession.id.value);
    final list = List<ChatwootConversation>.from(_conversations.value);
    if (!list.any((c) => c.id == created.id)) {
      list.add(created);
      _conversations.add(list);
    }
    return created;
  }

  @override
  Future<void> resolveConversation({
    required ChatwootConversationId id,
  }) async {
    final updated = await _repository.resolveConversation(
      sourceId: _requireSession.id.value,
      conversationId: id,
    );
    final list = List<ChatwootConversation>.from(_conversations.value);
    final i = list.indexWhere((c) => c.id == id);
    if (i >= 0) {
      list[i] = updated;
    } else {
      list.add(updated);
    }
    _conversations.add(list);
    _events.add(ChatwootEvent$ConversationStatusChanged(conversation: updated));
  }

  @override
  Future<void> toggleTyping({
    required ChatwootConversationId conversationId,
    required bool isTyping,
  }) {
    return _repository.toggleTyping(
      sourceId: _requireSession.id.value,
      conversationId: conversationId,
      isTyping: isTyping,
    );
  }

  @override
  Future<void> sendMessage({
    required ChatwootConversationId conversationId,
    String? content,
    List<XFile> attachments = const [],
  }) {
    return _repository.sendMessage(
      sourceId: _requireSession.id.value,
      conversationId: conversationId,
      content: content,
      attachments: attachments,
    );
  }

  @override
  Future<void> retryMessage({
    required ChatwootConversationId conversationId,
    required ChatwootMessage$Content$Outgoing message,
  }) {
    return _repository.retryMessage(
      sourceId: _requireSession.id.value,
      conversationId: conversationId,
      message: message,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _stopCableAndPresence();
    await _cable.disconnect();
    await _conversations.close();
    await _events.close();
  }
}
