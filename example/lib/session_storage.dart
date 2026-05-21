import 'dart:convert';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesSessionStorage implements SessionStorage {
  SharedPreferencesSessionStorage({required SharedPreferencesAsync preferences}) : _preferences = preferences;

  final SharedPreferencesAsync _preferences;

  static const _key = 'chatwoot_session';

  @override
  Future<StoredChatwootSession?> read() async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return StoredChatwootSession(
        sourceId: map['sourceId'] as String,
        identifier: map['identifier'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(StoredChatwootSession session) async {
    await _preferences.setString(
      _key,
      jsonEncode(<String, dynamic>{
        'sourceId': session.sourceId,
        'identifier': session.identifier,
      }),
    );
  }
}
