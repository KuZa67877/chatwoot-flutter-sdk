import 'package:meta/meta.dart';

import 'chatwoot_public_json.dart';

@immutable
final class ChatwootContactDto {
  const ChatwootContactDto({
    required this.id,
    required this.accountId,
    this.companyId,
    required this.additionalAttributes,
    required this.blocked,
    required this.customAttributes,
    this.email,
    this.identifier,
    this.lastActivityAt,
    required this.lastName,
    required this.location,
    required this.middleName,
    required this.name,
    this.phoneNumber,
  });

  final int id;
  final int accountId;
  final int? companyId;
  final Json additionalAttributes;
  final bool blocked;
  final Json customAttributes;
  final String? email;
  final String? identifier;
  final String? lastActivityAt;
  final String lastName;
  final String location;
  final String middleName;
  final String name;
  final String? phoneNumber;

  factory ChatwootContactDto.fromJson(Json json) {
    return ChatwootContactDto(
      id: json['id'] as int,
      accountId: json['account_id'] as int,
      companyId: json['company_id'] as int?,
      additionalAttributes: Map<String, dynamic>.from(json['additional_attributes'] as Map? ?? const {}),
      blocked: json['blocked'] as bool,
      customAttributes: Map<String, dynamic>.from(json['custom_attributes'] as Map? ?? const {}),
      email: json['email'] as String?,
      identifier: json['identifier'] as String?,
      lastActivityAt: json['last_activity_at'] as String?,
      lastName: json['last_name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      middleName: json['middle_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
    );
  }

  Json toJson() => {
    'id': id,
    'account_id': accountId,
    if (companyId != null) 'company_id': companyId,
    'additional_attributes': Map<String, dynamic>.from(additionalAttributes),
    'blocked': blocked,
    'custom_attributes': Map<String, dynamic>.from(customAttributes),
    if (email != null) 'email': email,
    if (identifier != null) 'identifier': identifier,
    if (lastActivityAt != null) 'last_activity_at': lastActivityAt,
    'last_name': lastName,
    'location': location,
    'middle_name': middleName,
    'name': name,
    if (phoneNumber != null) 'phone_number': phoneNumber,
  };
}
