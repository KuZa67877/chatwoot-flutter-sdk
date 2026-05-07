import 'dart:math';

import 'package:meta/meta.dart';

/// Backoff for WebSocket reconnect: exponential growth capped by [maxDelay], then fixed [maxDelay]
/// until [ChatwootSocket.disconnect] (no max attempt limit).
///
/// On the growth phase uses **full jitter**: delay is uniform in `[1, rawMs]` ms where `rawMs` is the
/// capped exponential value. On the plateau ([uncapped] ≥ [maxDelay]) delay is exactly [maxDelay].
@immutable
final class ChatwootSocketRetryPolicy {
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
}
