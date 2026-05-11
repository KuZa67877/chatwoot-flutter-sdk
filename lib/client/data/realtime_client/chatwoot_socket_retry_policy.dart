import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

@immutable
final class ChatwootSocketRetryContext {
  const ChatwootSocketRetryContext({
    required this.attemptIndex,
    required this.random,
    required this.cancelled,
    required this.previousSessionSucceeded,
  });

  /// `0` after the first failure, then increments per failure without a successful subscription in between.
  final int attemptIndex;

  /// Shared random source for policies that add jitter.
  final Random random;

  /// Completes when this reconnect wait should stop because the socket generation changed.
  final Future<void> cancelled;

  /// Whether the previous socket lifetime reached a confirmed subscription before closing.
  final bool previousSessionSucceeded;
}

/// Backoff for WebSocket reconnect: exponential growth capped by [maxDelay], then fixed [maxDelay]
/// until [ChatwootSocket.disconnect] (no max attempt limit).
///
/// On the growth phase uses **full jitter**: delay is uniform in `[1, rawMs]` ms where `rawMs` is the
/// capped exponential value. On the plateau ([uncapped] ≥ [maxDelay]) delay is exactly [maxDelay].
class ChatwootSocketRetryPolicy {
  ChatwootSocketRetryPolicy({
    this.initialDelay = const Duration(seconds: 1),
    this.multiplier = 2,
    this.maxDelay = const Duration(seconds: 30),
  }) : assert(multiplier > 1, 'multiplier must be > 1'),
       assert(initialDelay.inMilliseconds > 0, 'initialDelay must be positive'),
       assert(maxDelay >= initialDelay, 'maxDelay must be >= initialDelay');

  /// Delay before the first reconnect after a failed session (attempt index `0`).
  final Duration initialDelay;

  /// Exponential factor applied each failed attempt before hitting the cap.
  final num multiplier;

  /// Ceiling between reconnect attempts; used as fixed delay on plateau.
  final Duration maxDelay;

  static final ChatwootSocketRetryPolicy defaultPolicy = ChatwootSocketRetryPolicy();

  /// [attemptIndex] is `0` after the first failure, then increments per failure without a successful
  /// subscription in between. Successful connection resets the caller’s counter to `0`.
  Duration delayBeforeReconnect(int attemptIndex, Random random) {
    final initialMs = initialDelay.inMilliseconds;
    final maxMs = maxDelay.inMilliseconds;
    final uncapped = initialMs * pow(multiplier, attemptIndex);
    final plateau = uncapped >= maxMs;
    if (plateau) {
      return maxDelay;
    }
    final rawMs = uncapped.round().clamp(1, maxMs);
    // Full jitter in [1, rawMs].
    final ms = rawMs <= 1 ? 1 : random.nextInt(rawMs) + 1;
    return Duration(milliseconds: ms);
  }

  /// Waits until the next reconnect attempt is allowed.
  ///
  /// Subclasses can override this to gate reconnects on external signals such as connectivity,
  /// app lifecycle, or a manual retry trigger.
  Future<void> waitBeforeReconnect(ChatwootSocketRetryContext context) {
    final delay = delayBeforeReconnect(context.attemptIndex, context.random);
    return Future.any<void>([
      Future<void>.delayed(delay),
      context.cancelled,
    ]);
  }
}

/// Reconnect policy that waits for both the regular backoff and an online connectivity signal.
///
/// The SDK deliberately accepts a plain [Stream<bool>] instead of depending on a concrete connectivity
/// package. Pass `true` when the device is considered online and `false` when it is offline.
final class ChatwootSocketConnectivityRetryPolicy extends ChatwootSocketRetryPolicy {
  ChatwootSocketConnectivityRetryPolicy({
    required Stream<bool> connectivity,
    FutureOr<bool> Function()? checkConnectivity,
    bool? initialConnectivity,
    super.initialDelay,
    super.multiplier,
    super.maxDelay,
  }) : _connectivity = connectivity,
       _checkConnectivity = checkConnectivity,
       _lastKnownConnectivity = initialConnectivity;

  final Stream<bool> _connectivity;
  final FutureOr<bool> Function()? _checkConnectivity;
  bool? _lastKnownConnectivity;

  @override
  Future<void> waitBeforeReconnect(ChatwootSocketRetryContext context) async {
    final isOnline = await _isOnline();
    if (isOnline) {
      return super.waitBeforeReconnect(context);
    }

    final delay = delayBeforeReconnect(context.attemptIndex, context.random);
    await Future.any<void>([
      Future.wait<void>([
        Future<void>.delayed(delay),
        _waitUntilOnline(context.cancelled),
      ]),
      context.cancelled,
    ]);
  }

  Future<bool> _isOnline() async {
    final checkConnectivity = _checkConnectivity;
    if (checkConnectivity != null) {
      final isOnline = await checkConnectivity();
      _lastKnownConnectivity = isOnline;
      return isOnline;
    }

    return _lastKnownConnectivity ?? false;
  }

  Future<void> _waitUntilOnline(Future<void> cancelled) async {
    if (await _isOnline()) {
      return;
    }

    final completer = Completer<void>();
    late final StreamSubscription<bool> subscription;

    void complete() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    void completeError(Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }

    subscription = _connectivity.listen(
      (isOnline) {
        _lastKnownConnectivity = isOnline;
        if (isOnline) {
          unawaited(subscription.cancel());
          complete();
        }
      },
      onError: completeError,
      cancelOnError: true,
    );

    unawaited(
      cancelled.whenComplete(() async {
        await subscription.cancel();
        complete();
      }),
    );

    return completer.future;
  }
}
