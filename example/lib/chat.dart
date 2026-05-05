import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesSessionStorage implements SessionStorage {
  SharedPreferencesSessionStorage({required SharedPreferencesAsync preferences}) : _preferences = preferences;

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() async {
    return _preferences.getString('session');
  }

  @override
  Future<void> save(String sessionId) async {
    await _preferences.setString('session', sessionId);
  }
}

/// Корень example: авторизация, затем список обращений.
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
    _client = ChatwootClient(
      inboxIdentifier: inboxIdentifier,
      baseUrl: Uri.parse(baseUrlString),
      sessionStorage: SharedPreferencesSessionStorage(preferences: SharedPreferencesAsync()),
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final client = _client;
    try {
      await client.init();
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
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
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

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({super.key, required this.client});

  final ChatwootClient client;

  String _statusLabel(ChatwootConversationStatus status) {
    return switch (status) {
      ChatwootConversationStatus.open => 'Открыт',
      ChatwootConversationStatus.resolved => 'Закрыт',
      ChatwootConversationStatus.pending => 'В ожидании',
      ChatwootConversationStatus.snoozed => 'Отложен',
    };
  }

  Future<void> _openChat(BuildContext context, int conversationId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ConversationChatPage(
          client: client,
          conversationId: conversationId,
        ),
      ),
    );
    await client.refreshConversations();
  }

  Future<void> _startNewConversation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await client.createConversation();
      if (!context.mounted) {
        return;
      }
      await _openChat(context, created.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось создать обращение: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обращения'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () async {
              try {
                await client.refreshConversations();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка обновления: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatwootConversation>>(
        stream: client.conversations,
        builder: (context, snapshot) {
          final list = snapshot.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Пока нет обращений.\nНажмите «Новое обращение» ниже.',
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
              return ListTile(
                title: Text('Обращение #${c.id}'),
                subtitle: Text(_statusLabel(c.status)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openChat(context, c.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewConversation(context),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Новое обращение'),
      ),
    );
  }
}

class ConversationChatPage extends StatefulWidget {
  const ConversationChatPage({
    super.key,
    required this.client,
    required this.conversationId,
  });

  final ChatwootClient client;
  final int conversationId;

  @override
  State<ConversationChatPage> createState() => _ConversationChatPageState();
}

class _ConversationChatPageState extends State<ConversationChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.client.sendMessage(
        content: text,
        conversationId: widget.conversationId,
      );
      _input.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не отправилось: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId;
    return StreamBuilder<ChatwootConversation?>(
      stream: widget.client.conversations.map((list) {
        for (final c in list) {
          if (c.id == id) {
            return c;
          }
        }
        return null;
      }),
      builder: (context, snap) {
        final conv = snap.data;
        final messages = conv?.messages ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Чат #$id'),
                if (conv?.supportTyping == true)
                  Text(
                    'Собеседник печатает…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final outgoing = m is ChatwootMessage$Outgoing;
                    final bg = outgoing
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest;
                    return Align(
                      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                        ),
                        child: Card(
                          color: bg,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(m.content ?? ''),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Сообщение…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
