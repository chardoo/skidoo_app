import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// Reading a room turned exactly one message blue.
///
/// Reading is a watermark, not an event about a single message: opening a
/// conversation with nine unread messages in it reads all nine, and the
/// sender should watch nine pairs of ticks turn at once. What arrived instead
/// was one, and often none.
///
/// The server was never the problem. `broadcast_read` has always sent
/// `message_ids` — the exact list `mark_read` wrote — on every frame, bulk or
/// single. The client parsed `up_to_message_id` and `message_id` and dropped
/// the list, which left it resolving a cursor against the loaded window:
///
///   * cursor present and loaded  → the range worked
///   * cursor present, not loaded → `upToMsg` null, fell through to the single
///                                  id, which a bulk ack does not carry →
///                                  **nothing marked at all**
///   * no cursor                  → the one named message, and no other
///
/// The middle case is the common one. The cursor names the newest message in
/// the room, which on the sender's screen is routinely below the page they
/// have scrolled to, or simply not fetched yet.
ChatMessage msg(
  String id, {
  String sender = 'me',
  int minutesAgo = 0,
  List<String> readBy = const [],
  List<String> deliveredTo = const [],
}) =>
    ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: sender,
      senderRole: 'user',
      content: id,
      createdAt: DateTime.utc(2026, 1, 1, 12).subtract(
        Duration(minutes: minutesAgo),
      ),
      readBy: readBy,
      deliveredTo: deliveredTo,
    );

/// Newest first, the order the room holds them in.
List<ChatMessage> get mine => [
      msg('m3', minutesAgo: 0),
      msg('m2', minutesAgo: 1),
      msg('m1', minutesAgo: 2),
    ];

List<String> readIds(List<ChatMessage>? out) =>
    (out ?? []).where((m) => m.readBy.contains('them')).map((m) => m.id).toList();

void main() {
  group('a read frame', () {
    test('marks every message it names, not just the first', () {
      final out = ChatRoomBloc.applyRead(
        mine,
        myUserId: 'me',
        readerId: 'them',
        messageIds: ['m1', 'm2', 'm3'],
        upToMessageId: 'm3',
      );

      expect(readIds(out), ['m3', 'm2', 'm1']);
    });

    // The regression. A bulk ack carries no `message_id`, so once the cursor
    // failed to resolve there was nothing left to fall back to.
    test('still lands when the cursor is not in the loaded window', () {
      final out = ChatRoomBloc.applyRead(
        mine,
        myUserId: 'me',
        readerId: 'them',
        messageIds: ['m1', 'm2', 'm3'],
        // A newer message the sender has not fetched.
        upToMessageId: 'm9-not-loaded',
      );

      expect(readIds(out), ['m3', 'm2', 'm1']);
    });

    // The cursor still earns its keep: it covers messages older than the ones
    // named, which a truncated `message_ids` may not reach.
    test('covers everything at or below the cursor', () {
      final out = ChatRoomBloc.applyRead(
        mine,
        myUserId: 'me',
        readerId: 'them',
        messageIds: const [],
        upToMessageId: 'm2',
      );

      expect(readIds(out), ['m2', 'm1']);
    });

    test('a read implies delivery', () {
      final out = ChatRoomBloc.applyRead(
        mine,
        myUserId: 'me',
        readerId: 'them',
        messageIds: ['m1'],
      );

      final m1 = out!.firstWhere((m) => m.id == 'm1');
      expect(m1.deliveredTo, contains('them'));
    });

    test('leaves other people\'s messages alone', () {
      final out = ChatRoomBloc.applyRead(
        [msg('theirs', sender: 'them'), ...mine],
        myUserId: 'me',
        readerId: 'them',
        upToMessageId: 'm3',
      );

      expect(readIds(out), ['m3', 'm2', 'm1']);
    });

    // Repeat frames are routine — the reader's second device, a reconnect
    // backfill — and each one used to rebuild the whole list.
    test('changes nothing the second time, and says so', () {
      final once = ChatRoomBloc.applyRead(
        mine,
        myUserId: 'me',
        readerId: 'them',
        messageIds: ['m1', 'm2', 'm3'],
      );

      final twice = ChatRoomBloc.applyRead(
        once!,
        myUserId: 'me',
        readerId: 'them',
        messageIds: ['m1', 'm2', 'm3'],
      );

      expect(twice, isNull);
    });

    test('a frame naming nothing we hold changes nothing', () {
      final out = ChatRoomBloc.applyRead(
        mine,
        myUserId: 'me',
        readerId: 'them',
        messageIds: ['someone-elses-message'],
      );

      expect(out, isNull);
    });
  });
}
