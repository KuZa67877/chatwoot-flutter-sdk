import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Callback for Chatwoot envelopes: `{ event: string, data: object }`
/// as broadcast by [ActionCableBroadcastJob](https://github.com/chatwoot/chatwoot).
typedef ChatwootCableEnvelopeCallback = void Function(String event, Map<String, dynamic> data);

/// Minimal ActionCable consumer for Chatwoot [RoomChannel] (contact session).
///
/// Subscribe identifier: `{ channel: RoomChannel, pubsub_token }`.
/// Presence: periodic `update_presence` like [BaseActionCableConnector](https://github.com/chatwoot/chatwoot/blob/v4.8.0/app/javascript/shared/helpers/BaseActionCableConnector.js).
final class ChatwootActionCableClient {
  ChatwootActionCableClient({
    required this.cableUri,
    required this.pubsubToken,
    required this.onEnvelope,
    this.onError,
    this.presenceInterval = const Duration(seconds: 20),
  });

  final Uri cableUri;
  final String pubsubToken;
  final ChatwootCableEnvelopeCallback onEnvelope;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Duration presenceInterval;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _presenceTimer;
  Timer? _subscribeFallbackTimer;
  bool _disposed = false;
  bool _subscribed = false;
  String? _identifierJson;

  void connect() {
    if (_disposed) {
      return;
    }
    disconnectSync();
    _identifierJson = jsonEncode(<String, Object?>{
      'channel': 'RoomChannel',
      'pubsub_token': pubsubToken,
    });
    try {
      _channel = WebSocketChannel.connect(cableUri);
      _subscription = _channel!.stream.listen(
        _onRawMessage,
        onError: (Object error, StackTrace stackTrace) {
          onError?.call(error, stackTrace);
        },
        onDone: () {},
        cancelOnError: false,
      );
      _subscribeFallbackTimer = Timer(const Duration(milliseconds: 800), () {
        if (_disposed || _subscribed) {
          return;
        }
        _sendSubscribe();
      });
    } catch (e, st) {
      onError?.call(e, st);
    }
  }

  void _onRawMessage(dynamic raw) {
    if (_disposed) {
      return;
    }
    final text = switch (raw) {
      final String s => s,
      final List<int> bytes => utf8.decode(bytes),
      _ => raw.toString(),
    };
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return;
      }
      json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    final type = json['type'] as String?;
    switch (type) {
      case 'welcome':
        _sendSubscribe();
        return;
      case 'ping':
        final pingMessage = json['message'];
        _sinkJson(<String, Object?>{'type': 'pong', 'message': pingMessage});
        return;
      case 'confirm_subscription':
        return;
      case 'disconnect':
        return;
      default:
        break;
    }

    final message = json['message'];
    if (message is Map) {
      final map = Map<String, dynamic>.from(message);
      final event = map['event'] as String?;
      final data = map['data'];
      if (event != null && data is Map) {
        onEnvelope(event, Map<String, dynamic>.from(data));
      }
    }
  }

  void _sendSubscribe() {
    if (_channel == null || _identifierJson == null || _subscribed) {
      return;
    }
    _sinkJson(<String, Object?>{
      'command': 'subscribe',
      'identifier': _identifierJson,
    });
    _subscribed = true;
    _subscribeFallbackTimer?.cancel();
    _subscribeFallbackTimer = null;
    _ensurePresence();
  }

  void _sinkJson(Map<String, Object?> payload) {
    if (_channel == null) {
      return;
    }
    _channel!.sink.add(jsonEncode(payload));
  }

  void _ensurePresence() {
    if (_presenceTimer != null) {
      return;
    }
    _presenceTimer = Timer.periodic(presenceInterval, (_) => _sendPresence());
    _sendPresence();
  }

  void _sendPresence() {
    if (_channel == null || _identifierJson == null) {
      return;
    }
    _sinkJson(<String, Object?>{
      'command': 'message',
      'identifier': _identifierJson,
      'data': jsonEncode(<String, Object?>{'action': 'update_presence'}),
    });
  }

  /// Clears timers and closes the socket without awaiting (for sync teardown paths).
  void disconnectSync() {
    _subscribeFallbackTimer?.cancel();
    _subscribeFallbackTimer = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _subscribed = false;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(channel.sink.close());
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _subscribeFallbackTimer?.cancel();
    _subscribeFallbackTimer = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _subscribed = false;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await channel.sink.close();
    }
  }
}
