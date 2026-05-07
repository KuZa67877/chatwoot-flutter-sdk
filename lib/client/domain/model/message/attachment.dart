import 'package:cross_file/cross_file.dart';
import 'package:meta/meta.dart';

@immutable
sealed class Attachment {
  const Attachment();
}

class Attachment$File extends Attachment {
  const Attachment$File({
    required this.file,
  });

  final XFile file;

  String toString() => 'Attachment\$Local(file: ${file.name})';
}

class Attachment$Link extends Attachment {
  const Attachment$Link({
    this.url,
    this.thumbnail,
  });

  /// Main asset URL; may be null if the server has not exposed a link yet ([ChatwootAttachmentDto.dataUrl]).
  final Uri? url;

  final Uri? thumbnail;

  String toString() => 'Attachment\$Link(url: $url, thumbnail: $thumbnail)';
}
