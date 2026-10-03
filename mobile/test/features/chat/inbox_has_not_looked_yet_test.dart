import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// "No messages yet", to somebody with a year of conversations.
///
/// Reported after a cold start: open the app from the icon, go to Chats, and
/// the old threads are not there — so you start a new chat with the person you
/// were already talking to, and now there are two.
///
/// The cause was that the inbox could not tell two situations apart. Before the
/// first load has read anything, the bloc holds no rooms and `isLoading` false
/// — which is exactly what somebody with no conversations holds — and the page
/// drew the empty state for both. [ChatRoomsState.isUnknown] is the
/// distinction: nothing is known about this inbox until a load has answered,
/// and until then the only honest thing to draw is the spinner.
ChatRoom room(String id) => ChatRoom(
      id: id,
      type: RoomType.direct,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('before anything has been read', () {
    test('a fresh state says it does not know', () {
      // The state the bloc is constructed with, and the one on screen for as
      // long as the cache read and the server call take.
      expect(const ChatRoomsState().isUnknown, isTrue);
    });

    test('which is not the same as an empty inbox', () {
      // Same rooms — none — and opposite answers. That is the whole fix.
      const unread = ChatRoomsState();
      const answered = ChatRoomsState(hasLoaded: true);

      expect(unread.rooms, answered.rooms);
      expect(unread.isUnknown, isTrue);
      expect(answered.isUnknown, isFalse);
    });
  });

  group('once a load has answered', () {
    test('an inbox with rooms in it is known', () {
      final state = const ChatRoomsState()
          .copyWith(rooms: [room('r1')], hasLoaded: true);

      expect(state.isUnknown, isFalse);
    });

    test('an inbox that really is empty is known too', () {
      // The server said so, so the page may say so.
      final state = const ChatRoomsState().copyWith(hasLoaded: true);

      expect(state.isUnknown, isFalse);
    });

    test('a pending invite alone counts as something to show', () {
      final state = const ChatRoomsState().copyWith(pendingInvites: [room('r2')]);

      expect(state.isUnknown, isFalse);
    });

    test('and the answer survives the next sync', () {
      // copyWith carries it; a later emit that does not mention hasLoaded must
      // not quietly put the screen back to "unknown" and flash the spinner.
      final loaded = const ChatRoomsState().copyWith(hasLoaded: true);

      expect(loaded.copyWith(isSyncing: true).isUnknown, isFalse);
    });
  });
}
