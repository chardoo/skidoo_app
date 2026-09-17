import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// Sending a photo or a clip.
///
/// Three complaints, one send:
///
///   1. The media only appeared once the upload finished. For a clip on a slow
///      connection that is many seconds of the app looking like it swallowed
///      the thing — and nothing about showing it needs the server, because the
///      file is on the device already.
///   2. The bubble blinked after it was sent. The server's echo replaced the
///      optimistic message under a new id, which the room read as an arrival
///      and replayed the entrance fade on.
///   3. It made a sound.
ChatMessage sending({
  String? imageUrl,
  String? localMediaPath,
  double? uploadProgress,
  bool isVideo = false,
}) =>
    ChatMessage(
      id: 'local_1',
      roomId: 'r1',
      senderId: 'me',
      senderRole: 'user',
      content: '',
      imageUrl: imageUrl,
      localMediaPath: localMediaPath,
      uploadProgress: uploadProgress,
      isVideo: isVideo,
      isLocal: true,
      createdAt: DateTime.utc(2026, 9, 17),
    );

Widget host(ChatMessage message) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessageBubble(message: message, isMe: true),
          ),
        ),
      ),
    );

void main() {
  group('the media is on screen before the upload is', () {
    testWidgets('a photo with no URL yet still draws', (t) async {
      // The heart of it: imageUrl is null because the server has never seen
      // this file. Before the fix the bubble was gated on the URL and so this
      // message drew nothing at all.
      await t.pumpWidget(host(sending(
        localMediaPath: '/tmp/picked.jpg',
        uploadProgress: 0.3,
      )));
      await t.pump();

      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('and shows how far along it is', (t) async {
      await t.pumpWidget(host(sending(
        localMediaPath: '/tmp/picked.jpg',
        uploadProgress: 0.3,
      )));
      await t.pump();

      final bar = t.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator).first,
      );
      // Determinate, not a spinner: on a clip over a slow line a spinner and a
      // hang look identical, and telling them apart is the entire point.
      expect(bar.value, closeTo(0.3, 0.001));
    });

    testWidgets('a clip plays from the file on disk', (t) async {
      await t.pumpWidget(host(sending(
        localMediaPath: '/tmp/picked.mp4',
        isVideo: true,
        uploadProgress: 0.1,
      )));
      await t.pump();

      final player = t.widget<JpergVideoPlayer>(find.byType(JpergVideoPlayer));
      // A file:// URL, which is the branch the player turns into a file
      // controller. Not the network one — there is no URL yet.
      expect(player.url, startsWith('file://'));
      expect(player.url, endsWith('picked.mp4'));
    });

    testWidgets('the progress ring goes when the upload lands', (t) async {
      await t.pumpWidget(host(sending(
        localMediaPath: '/tmp/picked.jpg',
        imageUrl: 'https://cdn.example.com/picked.jpg',
      )));
      await t.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the local copy is preferred once the URL exists', (t) async {
      // Both are present after the upload, and the local one wins for the rest
      // of the session: the sender has the file, so the swap should cost no
      // download and show no placeholder.
      await t.pumpWidget(host(sending(
        localMediaPath: '/tmp/picked.jpg',
        imageUrl: 'https://cdn.example.com/picked.jpg',
      )));
      await t.pump();

      expect(find.byType(Image), findsWidgets);
    });
  });

  group('no tone for a message this device sent', () {
    // The first guard — the echo's sender is me — is unchanged and still first.
    // These cover the second, independent one, which does not depend on the
    // echo's sender surviving encryption, on the id cache being warm, or on the
    // open room having been paused under the id the echo arrives with.
    bool play({
      String senderId = 'them',
      bool iJustSentHere = false,
      RoomType? roomType = RoomType.direct,
    }) =>
        ChatBackgroundService.shouldPlayDmSound(
          muted: false,
          senderId: senderId,
          myId: 'me',
          roomType: roomType,
          iJustSentHere: iJustSentHere,
        );

    test('an ordinary incoming DM still chimes', () {
      expect(play(), isTrue);
    });

    test('my own message never does', () {
      expect(play(senderId: 'me'), isFalse);
    });

    test('nor does one that arrives right after I sent in this room', () {
      // Even with a sender that does not look like me — which is the case the
      // first guard cannot catch and the reported symptom needs.
      expect(play(senderId: 'someone-unrecognisable', iJustSentHere: true),
          isFalse);
    });
  });

  group('the sent bubble does not blink when the echo lands', () {
    ChatMessage msg(String id, {String sender = 'me', bool isLocal = false}) =>
        ChatMessage(
          id: id,
          roomId: 'r1',
          senderId: sender,
          senderRole: 'user',
          content: 'hi',
          isLocal: isLocal,
          createdAt: DateTime.utc(2026, 9, 17),
        );

    test('the echo of my own message is not treated as an arrival', () {
      // The reported flicker: `local_1` goes, `srv_1` arrives, and the room
      // replayed the 220ms fade-from-nothing on a bubble already on screen.
      final settled = msg('srv_1');

      expect(
        idsToAnimate(
          newIds: {'srv_1'},
          messages: [settled],
          myUserId: 'me',
        ),
        isEmpty,
      );
    });

    test('a message from somebody else still animates', () {
      expect(
        idsToAnimate(
          newIds: {'srv_2'},
          messages: [msg('srv_2', sender: 'them')],
          myUserId: 'me',
        ),
        {'srv_2'},
      );
    });

    test('my own optimistic insert still animates', () {
      // The send itself should feel like something happened — it is only the
      // second, redundant playing that goes.
      expect(
        idsToAnimate(
          newIds: {'local_9'},
          messages: [msg('local_9', isLocal: true)],
          myUserId: 'me',
        ),
        {'local_9'},
      );
    });

    test('an echo and a real arrival in the same update are told apart', () {
      final result = idsToAnimate(
        newIds: {'srv_1', 'srv_2'},
        messages: [msg('srv_1'), msg('srv_2', sender: 'them')],
        myUserId: 'me',
      );

      expect(result, {'srv_2'});
    });
  });
}
