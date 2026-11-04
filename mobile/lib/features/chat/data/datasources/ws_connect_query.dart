import 'package:web_socket_channel/web_socket_channel.dart';

/// The web build. A browser cannot set headers on a WebSocket handshake, so
/// the token stays in the query string there — the server still accepts it,
/// and the exposure a URL carries is a server-log one, which is a different
/// risk on a page the user is already looking at.
WebSocketChannel openChatSocket(Uri uri, {required String token}) {
  final withToken = uri.replace(queryParameters: {
    ...uri.queryParameters,
    if (token.isNotEmpty) 'token': token,
  });
  return WebSocketChannel.connect(withToken);
}
