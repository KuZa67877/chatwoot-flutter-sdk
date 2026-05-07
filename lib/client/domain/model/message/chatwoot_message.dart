import 'package:chatwoot_sdk/client/domain/model/message/attachment.dart';
import 'package:chatwoot_sdk/client/domain/model/message/message_sender.dart';
import 'package:meta/meta.dart';

enum OutgoingMessageStatus {
  sending,
  delivered,
  failed,
}

@immutable
sealed class ChatwootMessage implements Comparable<ChatwootMessage> {
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

  @override
  int compareTo(ChatwootMessage other) {
    final time = sentAt.compareTo(other.sentAt);
    if (time != 0) {
      return time;
    }

    return content?.compareTo(other.content ?? '') ?? 0;
  }
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

  @override
  int get hashCode => Object.hash(id, echoId, sentAt, content, attachments, isDeleted);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatwootMessage$Content &&
        other.id == id &&
        other.echoId == echoId &&
        other.sentAt == sentAt &&
        other.content == content &&
        other.attachments == attachments &&
        other.isDeleted == isDeleted;
  }

  @override
  String toString() {
    return 'ChatwootMessage\$Content('
        'id: $id, '
        'echoId: $echoId, '
        'sentAt: $sentAt, '
        'content: $content, '
        'attachments: $attachments, '
        'isDeleted: $isDeleted'
        ')';
  }
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

  @override
  int get hashCode => Object.hash(id, echoId, sentAt, content, attachments, isDeleted, sender);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatwootMessage$Content$Incoming &&
        other.id == id &&
        other.echoId == echoId &&
        other.sentAt == sentAt &&
        other.content == content &&
        other.attachments == attachments &&
        other.isDeleted == isDeleted &&
        other.sender == sender;
  }

  @override
  String toString() {
    return 'ChatwootMessage\$Content\$Incoming('
        'id: $id, '
        'echoId: $echoId, '
        'sentAt: $sentAt, '
        'content: $content, '
        'attachments: $attachments, '
        'isDeleted: $isDeleted, '
        'sender: $sender'
        ')';
  }
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

  bool isSame(ChatwootMessage$Content$Outgoing other) {
    if ((echoId, other.echoId) case (
      final echoId?,
      final otherEchoId?,
    ) when echoId.isNotEmpty && otherEchoId.isNotEmpty) {
      return echoId == otherEchoId;
    }

    return id == other.id;
  }

  ChatwootMessage$Content$Outgoing copyWith({
    OutgoingMessageStatus? status,
    String? echoId,
    DateTime? sentAt,
    String? content,
    List<Attachment>? attachments,
    bool? isDeleted,
  }) => ChatwootMessage$Content$Outgoing(
    id: id,
    status: status ?? this.status,
    echoId: echoId ?? this.echoId,
    sentAt: sentAt ?? this.sentAt,
    content: content ?? this.content,
    attachments: attachments ?? this.attachments,
    isDeleted: isDeleted ?? this.isDeleted,
  );

  @override
  int get hashCode => Object.hash(id, echoId, sentAt, content, attachments, isDeleted, status);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatwootMessage$Content$Outgoing &&
        other.id == id &&
        other.echoId == echoId &&
        other.sentAt == sentAt &&
        other.content == content &&
        other.attachments == attachments &&
        other.isDeleted == isDeleted &&
        other.status == status;
  }

  @override
  String toString() {
    return 'ChatwootMessage\$Content\$Outgoing('
        'id: $id, '
        'echoId: $echoId, '
        'sentAt: $sentAt, '
        'content: $content, '
        'attachments: $attachments, '
        'isDeleted: $isDeleted, '
        'status: $status'
        ')';
  }
}

class ChatwootMessage$Activity extends ChatwootMessage {
  const ChatwootMessage$Activity({
    required super.id,
    required super.echoId,
    required super.sentAt,
    required super.content,
    required super.attachments,
  });

  @override
  int get hashCode => Object.hash(id, echoId, sentAt, content, attachments);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatwootMessage$Activity &&
        other.id == id &&
        other.echoId == echoId &&
        other.sentAt == sentAt &&
        other.content == content &&
        other.attachments == attachments;
  }

  @override
  String toString() {
    return 'ChatwootMessage\$Activity('
        'id: $id, '
        'echoId: $echoId, '
        'sentAt: $sentAt, '
        'content: $content, '
        'attachments: $attachments'
        ')';
  }
}
