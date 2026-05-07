import 'package:meta/meta.dart';

/// Persisted keys for restoring [`ChatwootSession`] / [`ChatwootContact.identifier`].
@immutable
class StoredChatwootSession {
  const StoredChatwootSession({
    required this.sourceId,
    required this.identifier,
  });

  /// Public API contact key (`source_id` / REST path segment).
  final String sourceId;

  /// Client-side identity string from [`AuthorizationCreds.identifier`], or `sourceId` when anonymous.
  final String? identifier;
}
