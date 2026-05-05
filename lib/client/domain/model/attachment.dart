import 'package:cross_file/cross_file.dart';
import 'package:meta/meta.dart';

@immutable
sealed class Attachment {
  const Attachment();
}

class Attachment$Local extends Attachment {
  const Attachment$Local({
    required this.file,
  });

  final XFile file;

  String toString() => 'Attachment\$Local(file: ${file.name})';
}

class Attachment$Remote extends Attachment {
  const Attachment$Remote({
    required this.url,
    this.thumbnail,
  });

  final Uri? thumbnail;
  final Uri url;

  String toString() => 'Attachment\$Remote(url: $url, thumbnail: $thumbnail)';
}
