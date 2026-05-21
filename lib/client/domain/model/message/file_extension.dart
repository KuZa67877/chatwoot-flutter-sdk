import 'package:meta/meta.dart';

extension type const FileExtension(String _value) implements String {
  @factory
  static FileExtension? fromPath(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return null;
    }
    final extension = fileName.substring(dot + 1).trim().toLowerCase();

    if (extension.isEmpty) {
      return null;
    }
    return FileExtension(extension);
  }
}
