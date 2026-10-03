import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// Sending while a room is still opening left the message on screen twice.
///
/// A room paints its cache first and fetches history after, and for a DM the
/// socket listeners are attached last of all — so the composer is live for the
/// whole of that. Send in that window and the message goes out for real, its
/// echo arrives before anything is listening for it, and the copy that reaches
/// the screen is the one inside the history response that was already in
/// flight. Merging history by id alone put that copy **next to** the bubble it
/// was a copy of: one send, two bubbles, until the room was reopened and
/// rebuilt from the single row that existed.
///
/// Waiting a beat before sending hid it, which is exactly how it was reported:
/// share straight after picking somebody and it posts twice; pause first and
/// it posts once.
ChatMessage mine({
  required String id,
  String? clientId,
  String content = 'Sports Finals\nhttps://jperg.com/e/e1',
  String? imageUrl = 'https://cdn.example.com/p1.jpg',
  bool isLocal = false,
  int minutesAgo = 0,
}) =>
    ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: 'me',
      senderRole: 'user',
      content: content,
      imageUrl: imageUrl,
      createdAt: DateTime.utc(2026, 10, 3, 12).subtract(
        Duration(minutes: minutesAgo),
      ),
      isLocal: isLocal,
      clientId: clientId,
    );

ChatMessage theirs({required String id, String content = 'hey'}) => ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: 'them',
      senderRole: 'photographer',
      content: content,
      imageUrl: null,
      createdAt: DateTime.utc(2026, 10, 3, 11),
    );

void main() {
  group('history folded into what is already on screen', () {
    test('the bug: a send that comes back in history retires its bubble', () {
      final held = [mine(id: 'local_1', clientId: 'local_1', isLocal: true)];
      final fresh = [
        mine(id: 'server_1', clientId: 'local_1'),
        theirs(id: 'server_0'),
      ];

      final out = ChatRoomBloc.foldHistory(held, fresh);

      expect(out.where((m) => m.isLocal), isEmpty,
          reason: 'the placeholder has been confirmed');
      expect(out.map((m) => m.id), ['server_1', 'server_0']);
    });

    test('and does so with the image URL stripped off the server copy', () {
      // What an encrypted send used to come back as. The id is what matches,
      // so nothing the server did to the payload matters.
      final held = [mine(id: 'local_1', clientId: 'local_1', isLocal: true)];
      final fresh = [mine(id: 'server_1', clientId: 'local_1', imageUrl: null)];

      expect(ChatRoomBloc.foldHistory(held, fresh), hasLength(1));
    });

    test('an older server with no client_id still reconciles', () {
      final held = [mine(id: 'local_1', clientId: 'local_1', isLocal: true)];
      final fresh = [mine(id: 'server_1')];

      expect(ChatRoomBloc.foldHistory(held, fresh), hasLength(1));
    });

    test('a send history has not caught up with is kept', () {
      // The other half: a bubble nobody has confirmed must survive the merge,
      // or sending during a sync would make the message vanish.
      final held = [mine(id: 'local_1', clientId: 'local_1', isLocal: true)];
      final fresh = [theirs(id: 'server_0')];

      final out = ChatRoomBloc.foldHistory(held, fresh);

      expect(out.map((m) => m.id), contains('local_1'));
      expect(out, hasLength(2));
    });
  });

  group('what a history fetch may never remove', () {
    test('a message already confirmed', () {
      // Only placeholders are ever dropped. A settled message matching on
      // content would otherwise be deleted by its own re-fetch.
      final held = [mine(id: 'server_1', clientId: 'local_1')];
      final fresh = [mine(id: 'server_1', clientId: 'local_1')];

      final out = ChatRoomBloc.foldHistory(held, fresh);

      expect(out.map((m) => m.id), ['server_1']);
    });

    test('somebody else\'s bubble, however alike', () {
      // Two devices can pick the same `local_<time>` id, and the fallback
      // comparison matches on content — so the sender is checked too.
      final held = [
        ChatMessage(
          id: 'local_1',
          roomId: 'r1',
          senderId: 'them',
          senderRole: 'photographer',
          content: 'ok',
          createdAt: DateTime.utc(2026, 10, 3, 12),
          isLocal: true,
          clientId: 'local_1',
        ),
      ];
      final fresh = [mine(id: 'server_1', clientId: 'local_1', content: 'ok')];

      expect(ChatRoomBloc.foldHistory(held, fresh), hasLength(2));
    });

    test('an unrelated message of mine', () {
      final held = [mine(id: 'local_9', clientId: 'local_9', isLocal: true)];
      final fresh = [mine(id: 'server_1', clientId: 'local_1')];

      expect(ChatRoomBloc.foldHistory(held, fresh), hasLength(2));
    });
  });

  test('the fold is still a merge: nothing is lost or doubled', () {
    final held = [
      mine(id: 'server_2', clientId: null, minutesAgo: 1),
      theirs(id: 'server_1'),
    ];
    final fresh = [
      theirs(id: 'server_1'),
      theirs(id: 'server_0', content: 'older'),
    ];

    final out = ChatRoomBloc.foldHistory(held, fresh);

    expect(out.map((m) => m.id), ['server_2', 'server_1', 'server_0'],
        reason: 'newest first, each one once');
  });
}
