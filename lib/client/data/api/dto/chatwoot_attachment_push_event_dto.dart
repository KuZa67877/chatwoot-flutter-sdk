import 'package:meta/meta.dart';

import 'chatwoot_public_json.dart';

@immutable
final class ChatwootAttachmentPushEventDto {
  const ChatwootAttachmentPushEventDto({
    required this.id,
    required this.messageId,
    required this.fileType,
    required this.accountId,
    this.extension,
    this.dataUrl,
    this.thumbUrl,
    this.fileSize,
    this.width,
    this.height,
    this.coordinatesLat,
    this.coordinatesLong,
    this.fallbackTitle,
    this.meta,
    this.transcribedText,
  });

  final int id;
  final int messageId;

  final String fileType;
  final int accountId;

  final String? extension;
  final String? dataUrl;
  final String? thumbUrl;
  final int? fileSize;
  final int? width;
  final int? height;
  final double? coordinatesLat;
  final double? coordinatesLong;
  final String? fallbackTitle;

  final Json? meta;

  final String? transcribedText;

  factory ChatwootAttachmentPushEventDto.fromJson(Json json) {
    return ChatwootAttachmentPushEventDto(
      id: json['id'] as int,
      messageId: json['message_id'] as int,
      fileType: json['file_type'] as String,
      accountId: json['account_id'] as int,
      extension: json['extension'] as String?,
      dataUrl: json['data_url'] as String?,
      thumbUrl: json['thumb_url'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      coordinatesLat: (json['coordinates_lat'] as num?)?.toDouble(),
      coordinatesLong: (json['coordinates_long'] as num?)?.toDouble(),
      fallbackTitle: json['fallback_title'] as String?,
      meta: json['meta'] != null ? Map<String, dynamic>.from(json['meta'] as Map) : null,
      transcribedText: json['transcribed_text'] as String?,
    );
  }

  Json toJson() => {
    'id': id,
    'message_id': messageId,
    'file_type': fileType,
    'account_id': accountId,
    'extension': ?extension,
    'data_url': ?dataUrl,
    'thumb_url': ?thumbUrl,
    'file_size': ?fileSize,
    'width': ?width,
    'height': ?height,
    'coordinates_lat': ?coordinatesLat,
    'coordinates_long': ?coordinatesLong,
    'fallback_title': ?fallbackTitle,
    if (meta case final meta?) 'meta': Map<String, dynamic>.from(meta),
    'transcribed_text': ?transcribedText,
  };
}
