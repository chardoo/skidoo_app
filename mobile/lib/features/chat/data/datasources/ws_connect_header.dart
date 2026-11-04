import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// dart:io — the mobile and desktop builds, where the handshake can carry
/// headers. See [openChatSocket] in ws_connect.dart for why that matters.
WebSocketChannel openChatSocket(Uri uri, {required String token}) {
  return IOWebSocketChannel.connect(
    uri,
    headers: {
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    },
  );
}
