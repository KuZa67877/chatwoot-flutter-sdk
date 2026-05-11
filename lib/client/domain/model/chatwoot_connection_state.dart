sealed class ChatwootConnectionState {
  const ChatwootConnectionState();
}

class ChatwootConnectionState$Connected extends ChatwootConnectionState {
  const ChatwootConnectionState$Connected({
    this.isReconnected = false,
  });

  final bool isReconnected;
}

class ChatwootConnectionState$Disconnected extends ChatwootConnectionState {
  const ChatwootConnectionState$Disconnected();
}

class ChatwootConnectionState$Reconnecting extends ChatwootConnectionState {
  const ChatwootConnectionState$Reconnecting();
}
