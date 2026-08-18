import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

LastMessage msg(String id, DateTime at, {String content = 'hi'}) => LastMessage(
      id: id,
      senderId: 'me',
      senderName: 'Me',
      content: content,
      createdAt: at,
    );

ChatRoom room(String id, {LastMessage? last}) => ChatRoom(
      id: id,
      type: RoomType.direct,
      createdAt: DateTime.utc(2026, 1, 1),
      lastMessage: last,
    );

void main() {
  final t1 = DateTime.utc(2026, 8, 18, 10, 0);
  final t2 = DateTime.utc(2026, 8, 18, 10, 5);

  group('pruneLive', () {
    test('a live preview the server has caught up with is dropped', () {
      final live = {'r1': msg('m2', t2)};
      final fresh = [room('r1', last: msg('m2', t2))];
      expect(ChatRoomsBloc.pruneLive(live, fresh), isEmpty);
    });

    test('a live preview still ahead of the server survives the sync', () {
      // The message the user just sent. The server's room list was built
      // before it landed, so blanking the tile here would put the previous
      // message back under their name — the bug this guards.
      final live = {'r1': msg('m2', t2, content: 'just sent this')};
      final fresh = [room('r1', last: msg('m1', t1))];

      final kept = ChatRoomsBloc.pruneLive(live, fresh);
      expect(kept.keys, ['r1']);
      expect(kept['r1']!.content, 'just sent this');
    });

    test('a room the sync did not return keeps its live preview', () {
      final live = {'r9': msg('m2', t2)};
      expect(ChatRoomsBloc.pruneLive(live, [room('r1')]).keys, ['r9']);
    });

    test('a room the server has no preview for keeps the live one', () {
      final live = {'r1': msg('m2', t2)};
      expect(ChatRoomsBloc.pruneLive(live, [room('r1')]).keys, ['r1']);
    });

    test('nothing live means nothing to keep', () {
      expect(ChatRoomsBloc.pruneLive({}, [room('r1', last: msg('m1', t1))]),
          isEmpty);
    });
  });

  group('mergeTimes', () {
    test('the fetched time wins when it is the later one', () {
      final merged = ChatRoomsBloc.mergeTimes({'r1': t2}, {'r1': t1});
      expect(merged['r1'], t2);
    });

    test('a live time ahead of the cache survives the sync', () {
      final merged = ChatRoomsBloc.mergeTimes({'r1': t1}, {'r1': t2});
      expect(merged['r1'], t2);
    });

    test('rooms known only in memory are not lost', () {
      // This is web, where the local DB is unavailable and every fetched map
      // comes back empty. Replacing outright used to re-order the whole inbox
      // on each visit to the tab.
      final merged = ChatRoomsBloc.mergeTimes({}, {'r1': t1, 'r2': t2});
      expect(merged, {'r1': t1, 'r2': t2});
    });

    test('an empty in-memory map leaves the fetched one untouched', () {
      final fetched = {'r1': t1};
      expect(ChatRoomsBloc.mergeTimes(fetched, {}), same(fetched));
    });
  });
}
