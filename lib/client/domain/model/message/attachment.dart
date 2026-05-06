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
    required this.url,
    this.thumbnail,
  });

  final Uri? thumbnail;
  final Uri url;

  String toString() => 'Attachment\$Remote(url: $url, thumbnail: $thumbnail)';
}
