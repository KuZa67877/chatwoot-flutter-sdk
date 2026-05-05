import 'package:meta/meta.dart';

@immutable
class AuthorizationCreds {
  const AuthorizationCreds({
    required this.identifier,
    required this.identifierHash,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.customAttributes,
  });

  final String identifier;
  final String identifierHash;
  final String name;
  final String email;
  final String phoneNumber;
  final Map<String, Object> customAttributes;
}
