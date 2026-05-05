abstract interface class SessionStorage {
  Future<String?> read();

  Future<void> save(String sessionId);
}
