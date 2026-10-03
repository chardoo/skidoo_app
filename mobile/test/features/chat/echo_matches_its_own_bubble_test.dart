import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// One send has to leave exactly one bubble.
///
/// The reported bug: share an event or a photo into a chat on Android and it
/// appears **twice** — until you leave the room and come back, when it is there
/// once. Two bubbles over one message is the signature of an echo the app did
/// not recognise: the optimistic copy stays on screen and the server's copy is
/// inserted beside it, and reopening the room rebuilds the list from the single
/// row that ever existed.
///
/// It was recognised by comparing fields — `content` and `imageUrl` — which
/// holds only as long as the server returns both untouched. It does not: it
/// `strip()`s the body, and on an encrypted send it stored no `image_url` at
/// all, so the echo of a shared photo came back carrying none.
///
/// So the sender stamps each outgoing frame with the bubble's own id and the
/// server returns it (see [ChatMessage.clientId]). These pin that the match is
/// by that id, that it survives a server that rewrites the payload, and that
/// the old field comparison still covers a server too old to send it back.
ChatMessage optimistic({
  String id = 'local_1',
  String content = 'Sports Finals\nhttps://jperg.com/e/e1',
  String? imageUrl = 'https://cdn.example.com/p1.jpg',
}) =>
    ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: 'me',
      senderRole: 'user',
      content: content,
      imageUrl: imageUrl,
      createdAt: DateTime.utc(2026, 10, 3),
      isLocal: true,
      clientId: id,
    );

ChatMessage echo({
  String? clientId = 'local_1',
  String content = 'Sports Finals\nhttps://jperg.com/e/e1',
  String? imageUrl = 'https://cdn.example.com/p1.jpg',
}) =>
    ChatMessage(
      id: 'server_1',
      roomId: 'r1',
      senderId: 'me',
      senderRole: 'user',
      content: content,
      imageUrl: imageUrl,
      createdAt: DateTime.utc(2026, 10, 3),
      clientId: clientId,
    );

void main() {
  group('by the id the sender sent', () {
    test('an echo claims the bubble it came from', () {
      expect(ChatRoomBloc.confirms(echo(), optimistic()), isTrue);
    });

    test('the bug: an echo with no image_url still claims it', () {
      // Exactly what an encrypted send used to come back as — the row was
      // persisted and broadcast with the attachment stripped off it.
      expect(
        ChatRoomBloc.confirms(echo(imageUrl: null), optimistic()),
        isTrue,
        reason: 'one share, one bubble, whatever the server did to the payload',
      );
    });

    test('and so does one whose body the server rewrote', () {
      expect(
        ChatRoomBloc.confirms(echo(content: 'Sports Finals'), optimistic()),
        isTrue,
      );
    });

    test('somebody else\'s bubble is not claimed', () {
      // Two sends in flight at once: each echo belongs to one of them.
      expect(
        ChatRoomBloc.confirms(echo(clientId: 'local_2'), optimistic()),
        isFalse,
      );
    });
  });

  group('without one', () {
    test('an older server falls back to the field comparison', () {
      expect(
        ChatRoomBloc.confirms(echo(clientId: null), optimistic()),
        isTrue,
      );
    });

    test('which is the comparison that could not see a rewritten payload', () {
      // Kept as documentation of why the id exists: this is the case that put
      // two bubbles on the screen.
      expect(
        ChatRoomBloc.confirms(
          echo(clientId: null, imageUrl: null),
          optimistic(),
        ),
        isFalse,
      );
    });
  });

  group('what is never a placeholder', () {
    test('a message already confirmed', () {
      final settled = ChatMessage(
        id: 'local_1',
        roomId: 'r1',
        senderId: 'me',
        senderRole: 'user',
        content: 'Sports Finals\nhttps://jperg.com/e/e1',
        imageUrl: 'https://cdn.example.com/p1.jpg',
        createdAt: DateTime.utc(2026, 10, 3),
        clientId: 'local_1',
      );

      expect(ChatRoomBloc.confirms(echo(), settled), isFalse);
    });
  });
}
