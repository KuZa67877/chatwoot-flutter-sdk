final class ChatwootApiException implements Exception {
  ChatwootApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ChatwootApiException($statusCode): $body';
}
