import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

void main() {
  group('ChatBackgroundService.shouldPlayDmSound', () {
    const me = 'user-me';
    const them = 'user-them';

    test('plays for an incoming direct message from someone else', () {
      expect(
        ChatBackgroundService.shouldPlayDmSound(
          muted: false,
          senderId: them,
          myId: me,
          roomType: RoomType.direct,
        ),
        isTrue,
      );
    });

    test('silent when notifications are muted in the app', () {
      expect(
        ChatBackgroundService.shouldPlayDmSound(
          muted: true,
          senderId: them,
          myId: me,
          roomType: RoomType.direct,
        ),
        isFalse,
      );
    });

    test('silent when we do not know who we are', () {
      // getUserId() answers '' when the keychain read fails, and `senderId ==
      // myId` is false against '' for every sender alive — so an empty id
      // turned the "don't chime at yourself" guard off entirely and the app
      // played a tone at the user's own outgoing messages.
      //
      // A missed chime is a missed chime. A chime at your own message is a bug
      // somebody hears every time they type.
      expect(
        ChatBackgroundService.shouldPlayDmSound(
          muted: false,
          senderId: me,
          myId: '',
          roomType: RoomType.direct,
        ),
        isFalse,
      );
      expect(
        ChatBackgroundService.shouldPlayDmSound(
          muted: false,
          senderId: them,
          myId: '',
          roomType: RoomType.direct,
        ),
        isFalse,
      );
    });

    test('silent for the user\'s own echoed message', () {
      expect(
        ChatBackgroundService.shouldPlayDmSound(
          muted: false,
          senderId: me,
          myId: me,
          roomType: RoomType.direct,
        ),
        isFalse,
      );
    });

    test('silent for non-DM rooms (group/event/global)', () {
      for (final t in [
        RoomType.group,
        RoomType.event,
        RoomType.eventPrivate,
        RoomType.global,
        RoomType.photo,
        RoomType.sample,
      ]) {
        expect(
          ChatBackgroundService.shouldPlayDmSound(
            muted: false,
            senderId: them,
            myId: me,
            roomType: t,
          ),
          isFalse,
          reason: 'should not play for $t',
        );
      }
    });

    test('plays for an uncached room — treated as a brand-new DM', () {
      expect(
        ChatBackgroundService.shouldPlayDmSound(
          muted: false,
          senderId: them,
          myId: me,
          roomType: null,
        ),
        isTrue,
      );
    });

    test('mute wins even for a valid incoming DM', () {
      expect(
        ChatBackgroundService.shouldPlayDmSound(
          muted: true,
          senderId: them,
          myId: me,
          roomType: null,
        ),
        isFalse,
      );
    });

    test('a system notice never chimes', () {
      // "X accepted group invite" is a notice about the room, not somebody
      // getting in touch — it arrives on the same stream as a real message.
      expect(
        ChatBackgroundService.shouldPlayDmSound(
          muted: false,
          senderId: them,
          myId: me,
          roomType: null,
          isSystem: true,
        ),
        isFalse,
      );
    });
  });
}
