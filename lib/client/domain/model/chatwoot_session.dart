import 'package:chatwoot_sdk/client/domain/model/chatwoot_contact.dart';
import 'package:meta/meta.dart';

@immutable
class ChatwootSession {
  const ChatwootSession({
    required this.sourceId,
    required this.pubsubToken,
    required this.contact,
  });

  final String sourceId;
  final String pubsubToken;

  final ChatwootContact contact;

  @override
  String toString() =>
      'ChatwootSession('
      'sourceId: $sourceId, '
      'contact: $contact'
      ')';
}
