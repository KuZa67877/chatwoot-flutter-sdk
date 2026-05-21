import 'package:chatwoot_sdk/client/domain/model/message/file_extension.dart';
import 'package:cross_file/cross_file.dart';
import 'package:meta/meta.dart';

enum AttachmentFileType {
  image,
  video,
  file;

  factory AttachmentFileType.fromChatwootValue(String value) {
    switch (value.toLowerCase().trim()) {
      case 'image':
        return AttachmentFileType.image;
      case 'video':
        return AttachmentFileType.video;
      default:
        return AttachmentFileType.file;
    }
  }

  factory AttachmentFileType.fromMimeType(String mimeType) {
    final normalized = mimeType.toLowerCase().trim();
    if (normalized.startsWith('image/')) {
      return AttachmentFileType.image;
    }
    if (normalized.startsWith('video/')) {
      return AttachmentFileType.video;
    }
    return AttachmentFileType.file;
  }

  factory AttachmentFileType.fromExtension(String extension) {
    switch (extension.toLowerCase().trim()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
      case 'heif':
        return AttachmentFileType.image;
      case 'mp4':
      case 'mov':
      case 'm4v':
      case 'avi':
      case 'webm':
      case 'mkv':
        return AttachmentFileType.video;
      default:
        return AttachmentFileType.file;
    }
  }
}


@immutable
sealed class Attachment {
  const Attachment();
}

class Attachment$File extends Attachment {
  const Attachment$File({
    required this.file,
    required this.fileType,
    this.fileName,
    this.fileSize,
  });

  static Future<Attachment$File> fromXFile(XFile file) async {
    int? fileSize;
    try {
      fileSize = await file.length();
    } on Object {
      fileSize = null;
    }

    final extension = FileExtension.fromPath(file.name);
    final mimeType = file.mimeType?.trim();

    final AttachmentFileType fileType;

    if (mimeType != null && mimeType.isNotEmpty) {
      fileType = AttachmentFileType.fromMimeType(mimeType);
    } else if (extension != null) {
      fileType = AttachmentFileType.fromExtension(extension);
    } else {
      fileType = AttachmentFileType.file;
    }

    return Attachment$File(
      file: file,
      fileName: file.name.isEmpty ? null : file.name,
      fileSize: fileSize,
      fileType: fileType,
    );
  }

  final XFile file;
  final String? fileName;

  /// File size in bytes, calculated from [XFile.length] when available.
  final int? fileSize;

  final AttachmentFileType fileType;

  String toString() {
    return 'Attachment\$Local('
        'file: ${file.name}, '
        'fileName: $fileName, '
        'fileSize: $fileSize, '
        'fileType: $fileType'
        ')';
  }
}

class Attachment$Link extends Attachment {
  const Attachment$Link({
    required this.id,
    required this.url,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    this.thumbnail,
  });

  final int id;

  final Uri url;

  final Uri? thumbnail;
  final String fileName;

  /// File size in bytes as reported by Chatwoot `file_size`.
  final int fileSize;

  final AttachmentFileType fileType;

  String toString() {
    return 'Attachment\$Link('
        'id: $id, '
        'url: $url, '
        'thumbnail: $thumbnail, '
        'fileName: $fileName, '
        'fileSize: $fileSize, '
        'fileType: $fileType'
        ')';
  }
}
