import 'package:chatwoot_sdk/client/domain/model/message/attachment.dart';
import 'package:meta/meta.dart';

import 'chatwoot_public_json.dart';

/// Subset of Chatwoot `Attachment#push_event_data` JSON needed for [Attachment$Link].
///
/// `data_url` / `thumb_url` may be absent or empty (e.g. file not yet attached on server).
@immutable
final class ChatwootAttachmentDto {
  const ChatwootAttachmentDto({
    required this.id,
    required this.fileSize,
    required this.fileType,
    this.dataUrl,
    this.thumbUrl,
  });

  factory ChatwootAttachmentDto.fromJson(Json json) {
    return ChatwootAttachmentDto(
      id: (json['id'] as num).toInt(),
      dataUrl: json['data_url'] as String?,
      thumbUrl: json['thumb_url'] as String?,
      fileSize: json['file_size'] as int,
      fileType: json['file_type'] as String,
    );
  }

  final int id;
  final String? dataUrl;
  final String? thumbUrl;

  /// File size in bytes from Chatwoot `file_size`.
  final int fileSize;

  final String fileType;

  Json toJson() => {
    'id': id,
    'data_url': ?dataUrl,
    'thumb_url': ?thumbUrl,
    'file_size': fileSize,
    'file_type': fileType,
  };

  @factory
  Attachment$Link toDomainLink() {
    final url = Uri.parse(dataUrl!);
    final resolvedFileName = _fileNameFromUri(url) ?? 'attachment-$id';

    return Attachment$Link(
      id: id,
      url: url,
      thumbnail: thumbUrl != null ? Uri.tryParse(thumbUrl!) : null,
      fileName: resolvedFileName,
      fileSize: fileSize,
      fileType: AttachmentFileType.fromChatwootValue(fileType),
    );
  }

  static String? _fileNameFromUri(Uri uri) {
    final segment = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    final value = segment?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
