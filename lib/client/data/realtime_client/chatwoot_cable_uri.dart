/// Builds the Chatwoot ActionCable WebSocket URI from the same [baseUrl] used by
/// [HttpChatwootClientApi] (application origin), with `pubsub_token` as a query param.
///
/// Scheme is `wss` when [baseUrl] is `https`, otherwise `ws`. Path is `[baseUrl.path]/cable`
/// (normalized; empty path yields `/cable`).
Uri chatwootCableUri(Uri baseUrl, String pubsubToken) {
  final scheme = baseUrl.scheme == 'https' ? 'wss' : 'ws';
  return baseUrl.replace(
    scheme: scheme,
    path: _cablePath(baseUrl.path),
    queryParameters: {'pubsub_token': pubsubToken},
  );
}

String _cablePath(String basePath) {
  if (basePath.isEmpty || basePath == '/') {
    return '/cable';
  }
  final trimmed = basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
  return '$trimmed/cable';
}
