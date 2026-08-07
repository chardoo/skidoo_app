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
  });
}
