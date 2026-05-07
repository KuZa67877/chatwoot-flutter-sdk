import 'package:meta/meta.dart';

@immutable
class ChatwootContact {
  const ChatwootContact({
    required this.id,
    required this.identifier,
    this.name,
    this.email,
    this.phoneNumber,
  });

  /// ID of the contact in the Chatwoot system.
  final int id;
  final String? identifier;
  final String? name;
  final String? email;
  final String? phoneNumber;

  @override
  String toString() =>
      'ChatwootContact('
      'id: $id, '
      'name: $name, '
      'email: $email, '
      'phoneNumber: $phoneNumber'
      ')';
}
