import 'package:chatwoot_sdk/client/domain/model/attachment.dart';
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

@immutable
sealed class ChatwootMessage {
  const ChatwootMessage({
    required this.id,
    this.echoId,
    required this.sentAt,
    this.content,
    this.attachments = const [],
  });

  final int id;
  final String? echoId;
  final String? content;
  final DateTime sentAt;

  final List<Attachment> attachments;
}

class ChatwootMessage$Incoming extends ChatwootMessage {
  const ChatwootMessage$Incoming({
    required super.id,
    required super.echoId,
    required super.sentAt,
    required this.sender,
    required super.content,
    required super.attachments,
  });

  final ChatwootMessageSender? sender;
}

enum OutgoingMessageStatus {
  sending,
  delivered,
  failed,
}

class ChatwootMessage$Outgoing extends ChatwootMessage {
  const ChatwootMessage$Outgoing({
    required super.id,
    required super.echoId,
    required super.sentAt,
    required super.content,
    required super.attachments,
    required this.status,
  });

  final OutgoingMessageStatus status;
}

class ChatwootMessage$Activity extends ChatwootMessage {
  const ChatwootMessage$Activity({
    required super.id,
    required super.echoId,
    required super.sentAt,
    required super.content,
    required super.attachments,
  });
}
