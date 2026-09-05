import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/services/auth_service.dart';

/// What the shared socket is live on, and when it lets go.
///
/// Written after an account turned up holding 144 Redis channels. None of it
/// was a leak: opening an event's or a photo's comment thread writes a
/// permanent membership row, and both ends then subscribed everything they knew
/// about — the server on connect, the app a moment later. The set was a record
/// of everything the person had ever glanced at, each entry its own channel
/// carrying comments to a socket nobody was reading with.
///
/// The rule is that a comment thread is delivered while somebody has it open or
/// on screen, and not otherwise. The server half is pinned in the chat
/// service's `test_ws_subscription_scope.py`; these pin the app half, which is
/// the one that can quietly undo it — a single `subscribeRoom` in a loop over
/// every known room puts all 144 back.
void main() {
  group('which rooms are comment threads', () {
    test('the three that are opened, read and left', () {
      expect(RoomType.event.isCommentThread, isTrue);
      expect(RoomType.photo.isCommentThread, isTrue);
      expect(RoomType.sample.isCommentThread, isTrue);
    });

    test('a conversation never is', () {
      // Delivery for these has to work with the app nowhere near the room —
      // that is what raises the notification. `global` is excluded too: one
      // permanent room for everyone costs a single channel, and nobody "opens"
      // it the way they open a thread.
      for (final type in [
        RoomType.direct,
        RoomType.group,
        RoomType.eventPrivate,
        RoomType.global,
      ]) {
        expect(type.isCommentThread, isFalse, reason: '$type');
      }
    });
  });

  group('two screens, one room', () {
    // An event card visible in the feed and the comment sheet opened from it
    // are the same room wanted by different things. Whoever leaves first must
    // not speak for the other.
    late ChatWebSocketService ws;

    setUp(() => ws = ChatWebSocketService(AuthService()));

    test('the last holder is the one that releases it', () {
      ws.subscribeRoom('r1', holder: WsRoomHolder.feed);
      ws.subscribeRoom('r1', holder: WsRoomHolder.room);

      // Sheet closed, card still on screen: the feed keeps its updates.
      expect(ws.unsubscribeRoom('r1', holder: WsRoomHolder.room), isFalse);
      // Card scrolled away too — now there is nobody left.
      expect(ws.unsubscribeRoom('r1', holder: WsRoomHolder.feed), isTrue);
    });

    test('one holder subscribing twice still lets go once', () {
      // Callers subscribe idempotently — every rooms refresh re-subscribes what
      // it already had. A count would read that as a stack that never unwinds.
      ws.subscribeRoom('r1', holder: WsRoomHolder.feed);
      ws.subscribeRoom('r1', holder: WsRoomHolder.feed);
      expect(ws.unsubscribeRoom('r1', holder: WsRoomHolder.feed), isTrue);
    });

    test('a room nobody asked for is not released', () {
      expect(ws.unsubscribeRoom('never-seen', holder: WsRoomHolder.room),
          isFalse);
    });

    test('holders are per room', () {
      ws.subscribeRoom('r1', holder: WsRoomHolder.feed);
      ws.subscribeRoom('r2', holder: WsRoomHolder.feed);
      expect(ws.unsubscribeRoom('r1', holder: WsRoomHolder.feed), isTrue);
      expect(ws.unsubscribeRoom('r2', holder: WsRoomHolder.feed), isTrue);
    });
  });

  group('nothing subscribes a thread on its own initiative', () {
    // Source-level, because the alternative is standing up a socket, a token
    // and a room join to observe one loop. What matters is the filter existing
    // at all: these are the three places that iterate rooms.
    late String background;
    late String discovery;
    late String room;

    setUpAll(() {
      background = File(
        'lib/features/chat/data/datasources/chat_background_service.dart',
      ).readAsStringSync();
      discovery = File(
        'lib/features/discovery/presentation/bloc/discovery_bloc.dart',
      ).readAsStringSync();
      room = File(
        'lib/features/chat/presentation/bloc/room/chat_room_bloc.dart',
      ).readAsStringSync();
    });

    test('the background service subscribes conversations only', () {
      // Both its loops — the one on connect and the one for rooms discovered
      // while connected — go through this.
      expect(background, contains('!r.type.isCommentThread'));
      expect(background, contains('_backgroundRooms(_rooms.values)'));
      expect(background, contains('_backgroundRooms(rooms)'));
    });

    test('leaving a thread is not undone by resuming it', () {
      // close() releases the thread and then calls resume() on the same room.
      // Without the guard, resume re-subscribes what was just let go.
      expect(background, contains('known.type.isCommentThread'));
    });

    test('the room screen releases the thread on the way out', () {
      expect(room, contains('_releaseCommentThread()'));
      expect(room, contains('if (!_isCommentThread) return;'));
    });

    test('a card scrolled off screen stops updating', () {
      // _onEventHidden used to be empty — true when the server subscribed
      // everything anyway, a per-card leak once it stopped.
      expect(discovery, contains('_subscribedRoomIds.remove(id)'));
      expect(discovery,
          contains('unsubscribeRoom(room.id, holder: WsRoomHolder.feed)'));
    });
  });
}
