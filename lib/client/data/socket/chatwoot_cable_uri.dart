/// Builds Chatwoot ActionCable URL (`/cable`) from the same origin as REST [httpBaseUrl].
///
/// Matches Chatwoot widget / Rails: `wss://host/cable` or `ws://host/cable`.
Uri chatwootCableUri(Uri httpBaseUrl) {
  final scheme = httpBaseUrl.scheme == 'https' ? 'wss' : 'ws';
  return Uri(
    scheme: scheme,
    host: httpBaseUrl.host,
    port: httpBaseUrl.hasPort ? httpBaseUrl.port : null,
    path: '/cable',
  );
}
