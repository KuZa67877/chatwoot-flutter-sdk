import 'package:chatwoot_sdk/client/data/session_storage/stored_chatwoot_session.dart';

abstract interface class SessionStorage {
  Future<StoredChatwootSession?> read();

  Future<void> save(StoredChatwootSession session);
}
