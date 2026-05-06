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
}
