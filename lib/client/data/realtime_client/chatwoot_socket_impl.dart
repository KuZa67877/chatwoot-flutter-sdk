import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_conversation_dto.dart';
import 'package:chatwoot_sdk/client/data/api/dto/chatwoot_message_dto.dart';
import 'package:chatwoot_sdk/client/data/realtime_client/chatwoot_cable_uri.dart';
import 'package:chatwoot_sdk/client/data/realtime_client/chatwoot_socket.dart';
import 'package:chatwoot_sdk/client/data/realtime_client/chatwoot_socket_retry_policy.dart';
import 'package:chatwoot_sdk/client/domain/model/chatwoot_connection_state.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatwootSocketImpl implements ChatwootSocket {
  ChatwootSocketImpl({
    required Uri baseUrl,
    ChatwootSocketRetryPolicy? retryPolicy,
  }) : _baseUrl = baseUrl,
       _retryPolicy = retryPolicy ?? ChatwootSocketRetryPolicy.defaultPolicy,
       _connectionState = BehaviorSubject<ChatwootConnectionState>.seeded(
         const ChatwootConnectionState$Disconnected(),
       ),
       _events = PublishSubject<ChatwootSocketEvent>();

  final Uri _baseUrl;
  final ChatwootSocketRetryPolicy _retryPolicy;

  final BehaviorSubject<ChatwootConnectionState> _connectionState;
  final PublishSubject<ChatwootSocketEvent> _events;

  int _generation = 0;
  bool _userDisconnected = false;
  bool _everHadSubscription = false;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Completer<void>? _connectCompleter;

  @override
  Stream<ChatwootConnectionState> get connectionState => _connectionState.stream;

  @override
  Stream<ChatwootSocketEvent> get events => _events.stream;

  @override
  Future<void> connect({
    required String sourceId,
    required String pubsubToken,
  }) async {
    _userDisconnected = false;
    // [sourceId]: required by [ChatwootSocket]; not sent on `RoomChannel` wire (resolved via [pubsubToken]).
    final _ = sourceId;

    _generation++;
    final gen = _generation;

    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete();
    }
    _connectCompleter = Completer<void>();
    final waitConnected = _connectCompleter!.future;

    await _disposeSocket();

    unawaited(
      Future<void>(() async {
        try {
          await _runLoop(gen, pubsubToken);
        } on Object catch (_) {}
      }),
    );

    return waitConnected;
  }

  @override
  Future<void> disconnect() async {
    _userDisconnected = true;
    _generation++;
    _everHadSubscription = false;

    await _disposeSocket();

    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete();
    }
    _connectCompleter = null;

    if (!_connectionState.isClosed) {
      _connectionState.add(const ChatwootConnectionState$Disconnected());
    }
  }

  Future<void> _runLoop(int gen, String pubsubToken) async {
    final rng = Random();
    var attempt = 0;

    while (!_userDisconnected && gen == _generation) {
      if (_everHadSubscription) {
        if (!_connectionState.isClosed) {
          _connectionState.add(const ChatwootConnectionState$Reconnecting());
        }
      }

      var sessionSucceeded = false;
      try {
        await _singleSocketLifetime(gen, pubsubToken);
        sessionSucceeded = true;
      } on Object catch (_) {
        // Expected on subscribe failure, abort, or wire errors before confirmation.
      }

      if (_userDisconnected || gen != _generation) {
        break;
      }

      if (sessionSucceeded) {
        attempt = 0;
      }

      final delay = _retryPolicy.delayBeforeReconnect(attempt, rng);
      if (!sessionSucceeded) {
        attempt++;
      }

      await Future<void>.delayed(delay);
      if (_userDisconnected || gen != _generation) {
        break;
      }
    }
  }

  Future<void> _singleSocketLifetime(int gen, String pubsubToken) async {
    if (pubsubToken.isEmpty) {
      throw StateError('pubsubToken empty');
    }

    final uri = chatwootCableUri(_baseUrl, pubsubToken);
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    final confirm = Completer<void>();
    final ended = Completer<void>();

    late final StreamSubscription<dynamic> sub;
    sub = channel.stream.listen(
      (dynamic data) {
        if (_userDisconnected || gen != _generation) {
          return;
        }
        _handleWireMessage(data, channel, confirm);
      },
      onError: (Object _, StackTrace __) {
        if (!confirm.isCompleted) {
          confirm.completeError(StateError('websocket error'));
        }
        if (!ended.isCompleted) {
          ended.complete();
        }
      },
      onDone: () {
        if (!confirm.isCompleted) {
          confirm.completeError(StateError('socket closed before subscription'));
        }
        if (!ended.isCompleted) {
          ended.complete();
        }
      },
      cancelOnError: false,
    );
    _subscription = sub;

    channel.sink.add(_subscribeJson(pubsubToken));

    await confirm.future;

    if (_userDisconnected || gen != _generation) {
      await sub.cancel();
      await channel.sink.close();
      throw StateError('aborted');
    }

    _everHadSubscription = true;
    if (!_connectionState.isClosed) {
      _connectionState.add(const ChatwootConnectionState$Connected());
    }

    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete();
    }

    await ended.future;

    await sub.cancel();
    _subscription = null;
    _channel = null;
  }

  static String _subscribeJson(String pubsubToken) {
    final identifier = jsonEncode({
      'channel': 'RoomChannel',
      'pubsub_token': pubsubToken,
    });
    return jsonEncode({'command': 'subscribe', 'identifier': identifier});
  }

  void _handleWireMessage(
    dynamic data,
    WebSocketChannel channel,
    Completer<void> confirm,
  ) {
    final String text;
    if (data is String) {
      text = data;
    } else if (data is List<int>) {
      text = utf8.decode(data);
    } else {
      return;
    }

    late final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return;
      }
      json = Map<String, dynamic>.from(decoded);
    } on Object catch (_) {
      return;
    }

    final typeRaw = json['type'];
    final typeStr = typeRaw is String ? typeRaw.toLowerCase() : '';

    switch (typeStr) {
      case 'welcome':
        return;
      case 'ping':
        final msg = json['message'];
        channel.sink.add(jsonEncode({'command': 'pong', 'message': msg}));
        return;
      case 'confirm_subscription':
        if (!confirm.isCompleted) {
          confirm.complete();
        }
        return;
      case 'reject_subscription':
        if (!confirm.isCompleted) {
          confirm.completeError(StateError('reject_subscription'));
        }
        return;
      default:
        break;
    }

    final payload = json['message'];
    if (payload is Map<String, dynamic>) {
      _handleChannelPayload(payload);
    } else if (payload is Map) {
      _handleChannelPayload(Map<String, dynamic>.from(payload));
    }
  }

  void _handleChannelPayload(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    final data = message['data'];
    if (event == null || data is! Map) {
      return;
    }
    final map = Map<String, dynamic>.from(data);

    switch (event) {
      case 'message.created':
        _emit(() => ChatwootSocketEvent$Message$Created(message: ChatwootMessageDto.fromJson(map)));
        return;
      case 'message.updated':
        _emit(() => ChatwootSocketEvent$Message$Updated(message: ChatwootMessageDto.fromJson(map)));
        return;
      case 'conversation.status_changed':
        _emit(() {
          final conversation = ChatwootConversationDto.fromJson(map);
          return ChatwootSocketEvent$Conversation$StatusChanged(conversation: conversation);
        });
        return;
      case 'conversation.typing_on':
        if (map['is_private'] != true) {
          final onConversation = _conversationDtoFromTypingEnvelope(map);
          if (onConversation != null && !_events.isClosed) {
            _events.add(ChatwootSocketEvent$Conversation$TypingOn(conversation: onConversation));
          }
        }
        return;
      case 'conversation.typing_off':
        final offConversation = _conversationDtoFromTypingEnvelope(map);
        if (offConversation != null && !_events.isClosed) {
          _events.add(ChatwootSocketEvent$Conversation$TypingOff(conversation: offConversation));
        }
        return;
      default:
        return;
    }
  }

  void _emit(ChatwootSocketEvent Function() build) {
    if (_events.isClosed) {
      return;
    }
    try {
      _events.add(build());
    } on Object catch (_) {}
  }

  static ChatwootConversationDto? _conversationDtoFromTypingEnvelope(Map<String, dynamic> data) {
    final conv = data['conversation'];
    if (conv is! Map) {
      return null;
    }
    try {
      return ChatwootConversationDto.fromJson(Map<String, dynamic>.from(conv));
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> _disposeSocket() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }
}
