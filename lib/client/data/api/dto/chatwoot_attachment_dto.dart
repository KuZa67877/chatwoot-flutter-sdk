import 'package:chatwoot_sdk/client/domain/model/message/attachment.dart';
import 'package:meta/meta.dart';

import 'chatwoot_public_json.dart';

/// Subset of Chatwoot `Attachment#push_event_data` JSON needed for [Attachment$Link].
///
/// `data_url` / `thumb_url` may be absent or empty (e.g. file not yet attached on server).
@immutable
final class ChatwootAttachmentDto {
  const ChatwootAttachmentDto({
    this.dataUrl,
    this.thumbUrl,
  });

  final String? dataUrl;
  final String? thumbUrl;

  factory ChatwootAttachmentDto.fromJson(Json json) {
    final dataRaw = json['data_url'];
    final thumbRaw = json['thumb_url'];
    return ChatwootAttachmentDto(
      dataUrl: dataRaw is String ? dataRaw : null,
      thumbUrl: thumbRaw is String ? thumbRaw : null,
    );
  }

  Json toJson() => {
    if (dataUrl != null) 'data_url': dataUrl,
    if (thumbUrl != null) 'thumb_url': thumbUrl,
  };

  Attachment$Link toDomainLink() {
    return Attachment$Link(
      url: _parseUri(dataUrl),
      thumbnail: _parseUri(thumbUrl),
    );
  }

  static Uri? _parseUri(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return Uri.tryParse(trimmed);
  }
}
