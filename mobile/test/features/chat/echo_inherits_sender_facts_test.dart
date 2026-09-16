import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// What the sender knew has to survive the round trip.
///
/// The reported bug: share a paid photo into a chat, the watermark is there,
/// and a few seconds later it is gone. The seconds are the round trip. When the
/// server echoes the message back, the bloc **removes the optimistic bubble and
/// replaces it** — so anything the echo does not carry is anything the sender
/// stops seeing.
///
/// The bloc already did this for `isVideo`, with a comment explaining why the
/// server may not echo it. `paidPreview` is the same kind of fact and was not
/// inherited, so it was dropped on every send.
ChatMessage message({
  String content = '',
  String? imageUrl = 'https://cdn.example.com/p1.jpg',
  bool isVideo = false,
  bool paidPreview = false,
  bool isLocal = false,
}) =>
    ChatMessage(
      id: isLocal ? 'local_1' : 'm1',
      roomId: 'r1',
      senderId: 'me',
      senderName: 'Me',
      senderRole: 'user',
      content: content,
      imageUrl: imageUrl,
      isVideo: isVideo,
      paidPreview: paidPreview,
      isLocal: isLocal,
      createdAt: DateTime.utc(2026, 9, 16),
    );

void main() {
  group('the paid-photo mark', () {
    test('survives an echo that does not carry it', () {
      // The bug, exactly.
      final echo = message(paidPreview: false);
      final optimistic = message(paidPreview: true, isLocal: true);

      expect(
        ChatRoomBloc.inheritFromOptimistic(echo, optimistic).paidPreview,
        isTrue,
      );
    });

    test('an ordinary share stays unmarked', () {
      final echo = message(paidPreview: false);
      final optimistic = message(paidPreview: false, isLocal: true);

      expect(
        ChatRoomBloc.inheritFromOptimistic(echo, optimistic).paidPreview,
        isFalse,
      );
    });

    test('an echo that does carry it is left as it is', () {
      final echo = message(paidPreview: true);

      expect(
        ChatRoomBloc.inheritFromOptimistic(echo, message(isLocal: true))
            .paidPreview,
        isTrue,
      );
    });
  });

  group('the video flag, which taught us this', () {
    test('survives an echo that does not carry it', () {
      final echo = message(isVideo: false);
      final optimistic = message(isVideo: true, isLocal: true);

      expect(
        ChatRoomBloc.inheritFromOptimistic(echo, optimistic).isVideo,
        isTrue,
      );
    });

    test('both flags can be carried at once', () {
      final echo = message();
      final optimistic =
          message(isVideo: true, paidPreview: true, isLocal: true);

      final out = ChatRoomBloc.inheritFromOptimistic(echo, optimistic);

      expect(out.isVideo, isTrue);
      expect(out.paidPreview, isTrue);
    });
  });

  group('guards', () {
    test('no optimistic message means nothing to inherit', () {
      final echo = message(paidPreview: false);

      expect(
        ChatRoomBloc.inheritFromOptimistic(echo, null).paidPreview,
        isFalse,
      );
    });

    test('a flag is only ever turned on, never off', () {
      // The optimistic message is the sender's claim about their own send. It
      // is not evidence that something the server asserts is false.
      final echo = message(isVideo: true, paidPreview: true);
      final optimistic =
          message(isVideo: false, paidPreview: false, isLocal: true);

      final out = ChatRoomBloc.inheritFromOptimistic(echo, optimistic);

      expect(out.isVideo, isTrue);
      expect(out.paidPreview, isTrue);
    });

    test('everything else on the echo is untouched', () {
      // The echo is the server's message — its id, its timestamp, its content.
      // Only the two sender-known flags are carried over.
      final echo = message(content: 'from the server');
      final out = ChatRoomBloc.inheritFromOptimistic(
        echo,
        message(content: 'optimistic', paidPreview: true, isLocal: true),
      );

      expect(out.id, echo.id);
      expect(out.content, 'from the server');
      expect(out.isLocal, isFalse);
    });
  });
}
