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

  @override
  String toString() =>
      'ChatwootSession('
      'id: $id, '
      'contact: $contact'
      ')';
}
