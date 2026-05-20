sealed class ChatwootSessionException implements Exception {
  const ChatwootSessionException();
}

final class ChatwootSessionException$ContactNotFound extends ChatwootSessionException {
  const ChatwootSessionException$ContactNotFound({
    required this.contactId,
    this.identifier,
    this.cause,
  });

  final String contactId;
  final String? identifier;
  final Object? cause;

  @override
  String toString() => 'ChatwootSessionException\$ContactNotFound(contactId: $contactId, identifier: $identifier)';
}
