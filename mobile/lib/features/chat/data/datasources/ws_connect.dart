import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_connect_query.dart' if (dart.library.io) 'ws_connect_header.dart'
    as impl;

/// Opening the chat socket with the session token somewhere it will not be
/// written down.
///
/// The token used to travel in the query string — `/chat/ws/me?token=eyJ…`.
/// TLS covers it on the wire, but a URL is the part of a request that gets
/// logged: reverse-proxy access logs, load-balancer logs, anything that
/// records a request line. This token carries the account's role and is good
/// for a year, so one log file is a year of somebody's session sitting in
/// plaintext on a disk nobody thinks of as holding credentials.
///
/// The chat service has accepted `Authorization: Bearer` on the upgrade
/// request all along — `extract_ws_token` lists it as the preferred source and
/// calls the query parameter legacy — so this is the app catching up with the
/// server rather than a protocol change. The query form still works, which is
/// what makes the fallback below safe and what keeps older builds running.
///
/// **Headers only exist on the dart:io side.** A browser cannot set them on a
/// WebSocket handshake at all, so the web build keeps the query parameter;
/// `client_type=web` is already how the server tells the two apart.
WebSocketChannel openChatSocket(Uri uri, {required String token}) =>
    impl.openChatSocket(uri, token: token);

/// The same socket, with the token back in the query string.
///
/// Kept as a fallback for one case: a proxy in front of the chat service that
/// drops `Authorization` on an upgrade request. It is a standard header and
/// nothing in this deployment is known to strip it, but "the whole of chat
/// stops working" is a bad way to find out otherwise — so a failed handshake
/// is retried the old way once, and the session remembers which one worked.
WebSocketChannel openChatSocketLegacy(Uri uri, {required String token}) {
  final withToken = uri.replace(queryParameters: {
    ...uri.queryParameters,
    if (token.isNotEmpty) 'token': token,
  });
  return WebSocketChannel.connect(withToken);
}
