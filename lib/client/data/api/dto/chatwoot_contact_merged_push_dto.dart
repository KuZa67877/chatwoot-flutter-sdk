import 'package:meta/meta.dart';

import 'chatwoot_public_json.dart';

/// Subset of contact merge payload when broadcast includes [pubsub_token] (widget refresh).
@immutable
final class ChatwootContactMergedPushDto {
  const ChatwootContactMergedPushDto({
    this.pubsubToken,
    this.raw = const {},
  });

  final String? pubsubToken;
  final Map<String, dynamic> raw;

  factory ChatwootContactMergedPushDto.fromJson(Json json) {
    return ChatwootContactMergedPushDto(
      pubsubToken: json['pubsub_token'] as String?,
      raw: Map<String, dynamic>.from(json),
    );
  }
}
