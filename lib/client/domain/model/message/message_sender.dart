import 'package:meta/meta.dart';

@immutable
class ChatwootMessageSender {
  const ChatwootMessageSender({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.thumbnail,
  });

  final int id;
  final Uri? avatarUrl;
  final Uri? thumbnail;
  final String? name;

  @override
  int get hashCode => Object.hash(id, name, avatarUrl, thumbnail);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatwootMessageSender &&
        other.id == id &&
        other.name == name &&
        other.avatarUrl == avatarUrl &&
        other.thumbnail == thumbnail;
  }

  @override
  String toString() {
    return 'ChatwootMessageSender('
        'id: $id, '
        'name: $name, '
        'avatarUrl: $avatarUrl, '
        'thumbnail: $thumbnail'
        ')';
  }
}
