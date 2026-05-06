import 'package:chatwoot_sdk/client/domain/model/message/attachment.dart';
import 'package:chatwoot_sdk/client/domain/model/message/message_sender.dart';
import 'package:meta/meta.dart';

enum OutgoingMessageStatus {
  sending,
  delivered,
  failed,
}

@immutable
sealed class ChatwootMessage {
  const ChatwootMessage({
    required this.id,
    required this.echoId,
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

sealed class ChatwootMessage$Content extends ChatwootMessage {
  const ChatwootMessage$Content({
    required this.isDeleted,
    required super.id,
    required super.echoId,
    required super.sentAt,
    required super.content,
    required super.attachments,
  });

  final bool isDeleted;
}

class ChatwootMessage$Content$Incoming extends ChatwootMessage$Content {
  const ChatwootMessage$Content$Incoming({
    required super.id,
    required super.echoId,
    required super.sentAt,
    required this.sender,
    required super.isDeleted,
    required super.content,
    required super.attachments,
  });

  final ChatwootMessageSender? sender;
}

class ChatwootMessage$Content$Outgoing extends ChatwootMessage$Content {
  const ChatwootMessage$Content$Outgoing({
    required this.status,
    required super.id,
    required super.echoId,
    required super.sentAt,
    required super.content,
    required super.attachments,
    required super.isDeleted,
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
