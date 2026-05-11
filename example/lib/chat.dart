import 'dart:async';
import 'dart:convert';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:example/local_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Session storage
// ---------------------------------------------------------------------------

class SharedPreferencesSessionStorage implements SessionStorage {
  SharedPreferencesSessionStorage({required SharedPreferencesAsync preferences}) : _preferences = preferences;

  final SharedPreferencesAsync _preferences;

  static const _key = 'chatwoot_session';

  @override
  Future<StoredChatwootSession?> read() async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return StoredChatwootSession(
        sourceId: map['sourceId'] as String,
        identifier: map['identifier'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(StoredChatwootSession session) async {
    await _preferences.setString(
      _key,
      jsonEncode(<String, dynamic>{
        'sourceId': session.sourceId,
        'identifier': session.identifier,
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat UI user ids & mapping Chatwoot -> flutter_chat_core
// ---------------------------------------------------------------------------

const String kSupportUserId = 'chatwoot_support';
const String kSystemUserId = 'chatwoot_system';

String contactUserId(ChatwootContact c) => 'contact_${c.id}';

String? _nonEmpty(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return s;
}

AuthorizationCreds authorizationCredsFromEnvironment() {
  const identifier = String.fromEnvironment('CHATWOOT_IDENTIFIER');
  const identifierHash = String.fromEnvironment('CHATWOOT_IDENTIFIER_HASH');
  const name = String.fromEnvironment('CHATWOOT_NAME');
  const email = String.fromEnvironment('CHATWOOT_EMAIL');
  const phone = String.fromEnvironment('CHATWOOT_PHONE_NUMBER');

  return AuthorizationCreds(
    identifier: _nonEmpty(identifier),
    identifierHash: _nonEmpty(identifierHash),
    name: _nonEmpty(name),
    email: _nonEmpty(email),
    phoneNumber: _nonEmpty(phone),
  );
}

bool _hasNetworkConnectivity(List<ConnectivityResult> results) {
  return results.any((result) => result != ConnectivityResult.none);
}

MessageStatus? _outgoingStatus(OutgoingMessageStatus s) {
  return switch (s) {
    OutgoingMessageStatus.sending => MessageStatus.sending,
    OutgoingMessageStatus.delivered => MessageStatus.delivered,
    OutgoingMessageStatus.failed => MessageStatus.error,
  };
}

String _chatwootMessageKey(ChatwootMessage m) {
  return switch (m) {
    ChatwootMessage$Content$Outgoing(:final echoId) when echoId != null && echoId.isNotEmpty => 'cw_echo_$echoId',
    _ => 'cw_id_${m.id}',
  };
}

Message _fileUiMessage({
  required String id,
  required String authorId,
  required DateTime sentAt,
  required XFile file,
  MessageStatus? status,
  required Map<String, dynamic> metadata,
}) {
  return Message.file(
    id: id,
    authorId: authorId,
    createdAt: sentAt.toUtc(),
    source: file.path,
    name: file.name,
    status: status,
    metadata: metadata,
  );
}

List<Message> chatwootMessagesToUi(
  List<ChatwootMessage> messages,
  String currentUserId,
) {
  final out = <Message>[];
  for (final m in messages) {
    out.addAll(_mapOneChatwootMessage(m, currentUserId));
  }
  return out;
}

Iterable<Message> _mapOneChatwootMessage(ChatwootMessage m, String currentUserId) sync* {
  Iterable<Message> contentMessages(
    ChatwootMessage$Content message, {
    required String authorId,
    required MessageStatus? status,
    required Map<String, dynamic> metadata,
  }) sync* {
    final trimmed = message.content?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      yield Message.text(
        id: '${_chatwootMessageKey(message)}_t',
        authorId: authorId,
        createdAt: message.sentAt.toUtc(),
        text: trimmed,
        status: status,
        metadata: metadata,
      );
    }

    var attachmentIndex = 0;
    for (final att in message.attachments) {
      final suffix = '${_chatwootMessageKey(message)}_a${attachmentIndex++}';
      switch (att) {
        case Attachment$File(:final file):
          yield _fileUiMessage(
            id: suffix,
            authorId: authorId,
            sentAt: message.sentAt,
            file: file,
            status: status,
            metadata: metadata,
          );
        case Attachment$Link(:final url, :final thumbnail):
          final uri = thumbnail ?? url;
          if (uri != null) {
            yield Message.image(
              id: suffix,
              authorId: authorId,
              createdAt: message.sentAt.toUtc(),
              source: uri.toString(),
              status: status,
              metadata: metadata,
            );
          } else {
            yield Message.text(
              id: suffix,
              authorId: authorId,
              createdAt: message.sentAt.toUtc(),
              text: '(attachment without a URL)',
              status: status,
              metadata: metadata,
            );
          }
      }
    }

    if ((trimmed == null || trimmed.isEmpty) && message.attachments.isEmpty) {
      yield Message.text(
        id: _chatwootMessageKey(message),
        authorId: authorId,
        createdAt: message.sentAt.toUtc(),
        text: '(empty message)',
        status: status,
        metadata: metadata,
      );
    }
  }

  switch (m) {
    case ChatwootMessage$Activity():
      yield Message.system(
        id: _chatwootMessageKey(m),
        authorId: kSystemUserId,
        createdAt: m.sentAt.toUtc(),
        text: m.content ?? '',
      );
    case ChatwootMessage$Content$Incoming():
      yield* contentMessages(
        m,
        authorId: kSupportUserId,
        status: null,
        metadata: <String, dynamic>{
          'chatwootMessageId': m.id,
        },
      );
    case ChatwootMessage$Content$Outgoing(:final echoId, :final status):
      yield* contentMessages(
        m,
        authorId: currentUserId,
        status: _outgoingStatus(status),
        metadata: <String, dynamic>{
          'chatwootMessageId': m.id,
          if (echoId != null) 'chatwootEchoId': echoId,
          if (status == OutgoingMessageStatus.failed) 'failedOutgoing': true,
        },
      );
  }
}

// ---------------------------------------------------------------------------
// Root
// ---------------------------------------------------------------------------

/// Example root: bootstraps the client, then shows the conversation list.
class ChatwootExampleRoot extends StatefulWidget {
  const ChatwootExampleRoot({super.key});

  @override
  State<ChatwootExampleRoot> createState() => _ChatwootExampleRootState();
}

class _ChatwootExampleRootState extends State<ChatwootExampleRoot> {
  late final ChatwootClient _client;

  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    const inboxIdentifier = String.fromEnvironment('CHATWOOT_INBOX_IDENTIFIER');
    const baseUrlString = String.fromEnvironment('CHATWOOT_BASE_URL');

    final baseUri = baseUrlString.trim().isEmpty ? Uri.parse('https://app.chatwoot.com') : Uri.parse(baseUrlString);
    final connectivity = Connectivity();

    _client = ChatwootClientImpl.withHttpSocket(
      inboxIdentifier: inboxIdentifier,
      baseUrl: baseUri,
      sessionStorage: SharedPreferencesSessionStorage(preferences: SharedPreferencesAsync()),
      defaultCreds: authorizationCredsFromEnvironment(),
      retryPolicy: ChatwootSocketConnectivityRetryPolicy(
        connectivity: connectivity.onConnectivityChanged.map(_hasNetworkConnectivity).distinct(),
        checkConnectivity: () async => _hasNetworkConnectivity(await connectivity.checkConnectivity()),
      ),
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _client.bootstrap();
      if (mounted) {
        setState(() => _ready = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_client.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$_error', textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ConversationListPage(client: _client);
  }
}

// ---------------------------------------------------------------------------
// Conversation list
// ---------------------------------------------------------------------------

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key, required this.client});

  final ChatwootClient client;

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  StreamSubscription<ChatwootState>? _statesSub;
  StreamSubscription<ChatwootConnectionState>? _connectionSub;
  ChatwootConnectionState _connection = const ChatwootConnectionState$Disconnected();

  @override
  void initState() {
    super.initState();
    _statesSub = widget.client.statesStream.listen(_onClientState);
    _connectionSub = widget.client.connectionState.listen((s) {
      if (mounted) setState(() => _connection = s);
    });
  }

  void _onClientState(ChatwootState event) {
    if (!mounted) return;
    switch (event) {
      case ChatwootState$Message$New(:final message):
        switch (message) {
          case ChatwootMessage$Content$Incoming():
            break;
          case ChatwootMessage$Activity():
          case ChatwootMessage$Content$Outgoing():
            return;
        }
        final preview = message.content?.trim();
        final text = preview == null || preview.isEmpty ? 'New message' : preview;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
        );
      case ChatwootState$ConversationsLoaded():
      case ChatwootState$Message$Updated():
      case ChatwootState$Conversation():
        return;
    }
  }

  @override
  void dispose() {
    unawaited(_statesSub?.cancel());
    unawaited(_connectionSub?.cancel());
    super.dispose();
  }

  String _statusLabel(ChatwootConversationStatus status) {
    return switch (status) {
      ChatwootConversationStatus.open => 'Open',
      ChatwootConversationStatus.resolved => 'Resolved',
      ChatwootConversationStatus.pending => 'Pending',
      ChatwootConversationStatus.snoozed => 'Snoozed',
    };
  }

  String _connectionLabel() {
    return switch (_connection) {
      ChatwootConnectionState$Connected() => 'Online',
      ChatwootConnectionState$Disconnected() => 'Disconnected',
      ChatwootConnectionState$Reconnecting() => 'Reconnecting...',
    };
  }

  IconData _connectionIcon() {
    return switch (_connection) {
      ChatwootConnectionState$Connected() => Icons.cloud_done_outlined,
      ChatwootConnectionState$Disconnected() => Icons.cloud_off_outlined,
      ChatwootConnectionState$Reconnecting() => Icons.sync,
    };
  }

  String? _lastMessagePreview(ChatwootConversation c) {
    final msgs = c.messages;
    if (msgs.isEmpty) return null;
    final last = msgs.last;
    final t = last.content?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (last.attachments.isNotEmpty) return 'Attachment';
    return null;
  }

  ChatwootConversation? _conversationFromState(ChatwootConversationId id) {
    for (final c in widget.client.state.conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _openChat(BuildContext context, ChatwootConversation conversation) async {
    await widget.client.markConversationRead(id: conversation.id);
    if (!context.mounted) return;
    final uid = contactUserId(widget.client.contact);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ConversationChatPage(
          client: widget.client,
          initialConversation: _conversationFromState(conversation.id) ?? conversation,
          currentUserId: uid,
        ),
      ),
    );
    await widget.client.refreshConversations();
  }

  Future<void> _startNewConversation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await widget.client.createConversation();
      if (!context.mounted) {
        return;
      }
      await _openChat(context, created);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not create conversation: $e')));
    }
  }

  Future<void> _showProfile(BuildContext context) async {
    final nameCtrl = TextEditingController(text: widget.client.contact.name ?? '');
    final emailCtrl = TextEditingController(text: widget.client.contact.email ?? '');
    final phoneCtrl = TextEditingController(text: widget.client.contact.phoneNumber ?? '');

    final idCtrl = TextEditingController(text: widget.client.contact.identifier ?? '');
    final idHashCtrl = TextEditingController(text: '');
    final switchNameCtrl = TextEditingController(text: '');
    final switchEmailCtrl = TextEditingController(text: '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.paddingOf(ctx).bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Contact', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('id: ${widget.client.contact.id}', style: Theme.of(ctx).textTheme.bodySmall),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    try {
                      await widget.client.updateContact(
                        name: _nonEmpty(nameCtrl.text),
                        email: _nonEmpty(emailCtrl.text),
                        phoneNumber: _nonEmpty(phoneCtrl.text),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact updated')));
                        setState(() {});
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Save contact'),
                ),
                const Divider(height: 32),
                Text('Switch identity (authorize)', style: Theme.of(ctx).textTheme.titleMedium),
                TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'identifier')),
                TextField(controller: idHashCtrl, decoration: const InputDecoration(labelText: 'identifierHash')),
                TextField(controller: switchNameCtrl, decoration: const InputDecoration(labelText: 'Name (optional)')),
                TextField(
                    controller: switchEmailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)')),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await widget.client.authorize(
                        AuthorizationCreds(
                          identifier: _nonEmpty(idCtrl.text),
                          identifierHash: _nonEmpty(idHashCtrl.text),
                          name: _nonEmpty(switchNameCtrl.text),
                          email: _nonEmpty(switchEmailCtrl.text),
                          phoneNumber: null,
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Authorization completed')));
                        setState(() {});
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('authorize: $e')));
                      }
                    }
                  },
                  child: const Text('authorize(...)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await widget.client.logout();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('logout(): new session from defaultCreds')));
                        setState(() {});
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('logout: $e')));
                      }
                    }
                  },
                  child: const Text('logout()'),
                ),
              ],
            ),
          ),
        );
      },
    );

    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    idCtrl.dispose();
    idHashCtrl.dispose();
    switchNameCtrl.dispose();
    switchEmailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.client.contact;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Conversations'),
            Text(
              '${contact.name ?? contact.identifier ?? 'Contact'} · ${_connectionLabel()}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          Icon(_connectionIcon(), color: Theme.of(context).colorScheme.onSurfaceVariant),
          IconButton(
            tooltip: 'Profile and session',
            onPressed: () => _showProfile(context),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              try {
                await widget.client.refreshConversations();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refresh failed: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<ChatwootState>(
        stream: widget.client.statesStream,
        initialData: widget.client.state,
        builder: (context, snapshot) {
          final state = snapshot.data;
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = state.conversations;
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No conversations yet.\nTap "New conversation" below.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = list[index];
              final preview = _lastMessagePreview(c);
              final subtitle = StringBuffer(_statusLabel(c.status));
              if (preview != null) {
                subtitle.write(' · ');
                subtitle.write(preview);
              }
              return ListTile(
                title: Text('Conversation #${c.id}'),
                subtitle: Text(subtitle.toString()),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CircleAvatar(
                          radius: 12,
                          child: Text(
                            '${c.unreadCount}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openChat(context, c),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewConversation(context),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New conversation'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat page (flutter_chat_ui)
// ---------------------------------------------------------------------------

class ConversationChatPage extends StatefulWidget {
  const ConversationChatPage({
    super.key,
    required this.client,
    required this.initialConversation,
    required this.currentUserId,
  });

  final ChatwootClient client;
  final ChatwootConversation initialConversation;
  final String currentUserId;

  ChatwootConversationId get conversationId => initialConversation.id;

  @override
  State<ConversationChatPage> createState() => _ConversationChatPageState();
}

class _ConversationChatPageState extends State<ConversationChatPage> {
  late final InMemoryChatController _chatController;
  late final TextEditingController _composerController;

  StreamSubscription<ChatwootState>? _stateSub;

  Timer? _typingCooldown;
  bool _typingActive = false;
  bool _markingRead = false;

  ChatwootConversation? _latestConversation;

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController();
    _composerController = TextEditingController();
    _composerController.addListener(_onComposerChanged);
    _latestConversation = widget.initialConversation;

    unawaited(_syncMessages(widget.initialConversation));
    _stateSub = widget.client.statesStream.listen(_onClientState);
    unawaited(_markCurrentConversationRead());
  }

  void _onComposerChanged() {
    final hasText = _composerController.text.trim().isNotEmpty;
    if (hasText) {
      _signalTyping(true);
      _typingCooldown?.cancel();
      _typingCooldown = Timer(const Duration(seconds: 2), () => _signalTyping(false));
    } else {
      _typingCooldown?.cancel();
      unawaited(_signalTyping(false));
    }
  }

  Future<void> _signalTyping(bool typing) async {
    if (typing) {
      if (_typingActive) return;
      _typingActive = true;
      try {
        await widget.client.toggleTyping(
          conversationId: widget.conversationId,
          isTyping: true,
        );
      } on Object {
        // ignore
      }
      return;
    }

    _typingCooldown?.cancel();
    if (!_typingActive) return;
    _typingActive = false;
    try {
      await widget.client.toggleTyping(
        conversationId: widget.conversationId,
        isTyping: false,
      );
    } on Object {
      // ignore
    }
  }

  void _onClientState(ChatwootState state) {
    _latestConversation = state.conversations.firstWhere((c) => c.id == widget.conversationId);
    switch (state) {
      case ChatwootState$ConversationsLoaded(:final conversations):
        _syncConversationList(conversations);
      case ChatwootState$Conversation(:final conversation) when conversation.id == widget.conversationId:
        _syncConversation(conversation);
      case ChatwootState$Conversation():
        return;
      case ChatwootState$Message$New(:final conversationId, :final message)
          when conversationId == widget.conversationId:
        _chatController.insertAllMessages(_mapOneChatwootMessage(message, widget.currentUserId).toList());
        return;
      case ChatwootState$Message$Updated(:final conversationId, :final messageIndex, :final message)
          when conversationId == widget.conversationId:
        final oldMessage = _chatController.messages[messageIndex];
        final messages = _mapOneChatwootMessage(message, widget.currentUserId);
        _chatController.updateMessage(
          oldMessage,
          messages.first,
        );
        return;
      case ChatwootState$Message$New():
      case ChatwootState$Message$Updated():
        return;
    }
  }

  void _syncConversationList(List<ChatwootConversation> conversations) {
    for (final c in conversations) {
      if (c.id == widget.conversationId) {
        _syncConversation(c);
        return;
      }
    }
  }

  void _syncConversation(ChatwootConversation conversation) {
    _latestConversation = conversation;
    unawaited(_syncMessages(conversation));
    if (conversation.unreadCount > 0) {
      unawaited(_markCurrentConversationRead());
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncMessages(ChatwootConversation conversation) {
    final ui = chatwootMessagesToUi(conversation.messages, widget.currentUserId);
    return _chatController.setMessages(ui);
  }

  Future<void> _markCurrentConversationRead() async {
    if (_markingRead) {
      return;
    }
    _markingRead = true;
    try {
      await widget.client.markConversationRead(id: widget.conversationId);
    } on Object {
      // New state or manual refresh will try again if unread messages remain.
    } finally {
      _markingRead = false;
    }
  }

  Future<User?> _resolveUser(UserID id) async {
    if (id == widget.currentUserId) {
      final c = widget.client.contact;
      return User(id: id, name: c.name ?? 'You');
    }
    if (id == kSupportUserId) {
      return const User(id: kSupportUserId, name: 'Support');
    }
    if (id == kSystemUserId) {
      return const User(id: kSystemUserId, name: 'System');
    }
    return User(id: id, name: id);
  }

  Future<void> _onRefresh() async {
    await widget.client.refreshConversations();
  }

  Future<void> _onResolve() async {
    try {
      await widget.client.resolveConversation(id: widget.conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conversation resolved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('resolve: $e')));
      }
    }
  }

  Future<void> _pickAndSendAttachments() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;

    await _signalTyping(false);
    try {
      await widget.client.sendMessage(
        conversationId: widget.conversationId,
        attachments: files,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attachments: $e')));
      }
    }
  }

  Future<void> _retryFailed(Message uiMessage) async {
    final conv = _latestConversation;
    if (conv == null) return;

    final echoId = uiMessage.metadata?['chatwootEchoId'] as String?;
    final mid = uiMessage.metadata?['chatwootMessageId'] as int?;

    ChatwootMessage$Content$Outgoing? failed;
    for (final m in conv.messages) {
      switch (m) {
        case ChatwootMessage$Content$Outgoing(:final status) when status == OutgoingMessageStatus.failed:
          if (echoId != null && echoId.isNotEmpty && m.echoId == echoId) {
            failed = m;
            break;
          }
          if ((echoId == null || echoId.isEmpty) && m.id == mid) {
            failed = m;
            break;
          }
        case ChatwootMessage$Content$Outgoing():
        case ChatwootMessage$Content$Incoming():
        case ChatwootMessage$Activity():
          break;
      }
      if (failed != null) break;
    }

    if (failed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Original message for retry was not found')),
        );
      }
      return;
    }

    try {
      await widget.client.retryMessage(
        conversationId: widget.conversationId,
        message: failed,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('retry: $e')));
      }
    }
  }

  void _onMessageTap(
    BuildContext context,
    Message message, {
    required int index,
    required TapUpDetails details,
  }) {
    if (message.metadata?['failedOutgoing'] == true) {
      unawaited(_retryFailed(message));
    }
  }

  @override
  void dispose() {
    unawaited(_signalTyping(false));
    _typingCooldown?.cancel();
    unawaited(_stateSub?.cancel());
    _composerController.removeListener(_onComposerChanged);
    _composerController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleId = widget.conversationId;
    final conv = _latestConversation;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chat #$titleId'),
            if (conv?.supportTyping == true)
              Text(
                'Teammate is typing...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: () async {
              await _onRefresh();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Resolve conversation',
            onPressed: _onResolve,
            icon: const Icon(Icons.check_circle_outline),
          ),
        ],
      ),
      body: Chat(
        currentUserId: widget.currentUserId,
        resolveUser: _resolveUser,
        chatController: _chatController,
        theme: ChatTheme.light(),
        onMessageSend: (text) {
          unawaited(_signalTyping(false));
          final trimmed = text.trim();
          if (trimmed.isEmpty) return;
          unawaited(
            widget.client.sendMessage(
              conversationId: widget.conversationId,
              content: trimmed,
            ),
          );
        },
        onAttachmentTap: _pickAndSendAttachments,
        onMessageTap: _onMessageTap,
        builders: Builders(
          composerBuilder: (context) => Composer(
            textEditingController: _composerController,
            hintText: 'Message...',
            sendButtonVisibilityMode: SendButtonVisibilityMode.hidden,
            sendOnEnter: false,
            minLines: 1,
            maxLines: 6,
          ),
          textMessageBuilder: (context, message, index, {required isSentByMe, groupStatus}) {
            final failed = message.metadata?['failedOutgoing'] == true;
            return SimpleTextMessage(
              message: message,
              index: index,
              topWidget: failed
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Not delivered - tap to retry',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : null,
            );
          },
          imageMessageBuilder: (context, message, index, {required isSentByMe, groupStatus}) {
            return _ExampleNetworkOrFileImage(message: message);
          },
          fileMessageBuilder: (context, message, index, {required isSentByMe, groupStatus}) {
            return _ExampleFileTile(message: message);
          },
          systemMessageBuilder: (context, message, index, {required isSentByMe, groupStatus}) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      message.text,
                      style: Theme.of(context).textTheme.labelMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExampleNetworkOrFileImage extends StatelessWidget {
  const _ExampleNetworkOrFileImage({required this.message});

  final ImageMessage message;

  @override
  Widget build(BuildContext context) {
    final src = message.source;
    final borderRadius = BorderRadius.circular(12);
    Widget image;
    if (src.startsWith('http://') || src.startsWith('https://')) {
      image = Image.network(
        src,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    } else {
      image = localFileImage(src, fit: BoxFit.cover);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
        child: image,
      ),
    );
  }
}

class _ExampleFileTile extends StatelessWidget {
  const _ExampleFileTile({required this.message});

  final FileMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(message.name),
            subtitle: Text(
              message.source.startsWith('http') ? message.source : 'File: ${message.source}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
