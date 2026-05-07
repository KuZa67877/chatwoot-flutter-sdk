import 'package:chatwoot_sdk/client/domain/model/session/chatwoot_contact.dart';
import 'package:meta/meta.dart';

extension type ContactInboxId(String value) implements String {}

@immutable
class ChatwootSession {
  const ChatwootSession({
    required this.id,
    required this.token,
    required this.contact,
  });

  final ContactInboxId id;
  final String token;

  final ChatwootContact contact;

  ChatwootSession copyWith({
    ContactInboxId? id,
    String? token,
    ChatwootContact? contact,
  }) {
    return ChatwootSession(
      id: id ?? this.id,
      token: token ?? this.token,
      contact: contact ?? this.contact,
    );
  }

  @override
  String toString() =>
      'ChatwootSession('
      'id: $id, '
      'contact: $contact'
      ')';
}
