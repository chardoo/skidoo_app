import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// A liked comment has to still be liked when the sheet is opened again.
///
/// The reported bug, exactly: you tap the heart, it fills, you close the
/// comments and open them again, and the like is gone.
///
/// The server was never at fault — `/chat/likes/comment/{id}` recorded it and
/// both read paths reported it back correctly. The like was lost on the way
/// through the *phone*, in two places, and either one alone was enough to lose
/// it:
///
///  1. The local SQLite cache had no `like_count` / `viewer_liked` columns, so
///     every cached message was written back with an empty heart. The sheet
///     paints from that cache before any request goes out, which is why the
///     like appeared to survive right up until the sheet was reopened.
///  2. Nothing ever wrote the settled like onto the message. It lived in a map
///     inside the sheet's own State, which is thrown away when the sheet
///     closes — so even with the columns there was nothing to persist.
///
/// These cover the model half: that a `ChatMessage` carries the like, that
/// `copyWith` can move it, and that it round-trips through the JSON the cache
/// and the API both speak. The bloc half — writing it onto the message and into
/// the cache — is `_onCommentLikeSettled`.
void main() {
  ChatMessage comment({int likeCount = 0, bool viewerLiked = false}) =>
      ChatMessage(
        id: 'c1',
        roomId: 'r1',
        senderId: 'u2',
        senderName: 'Ama',
        senderRole: 'user',
        content: 'what a shot',
        createdAt: DateTime.utc(2026, 9, 16),
        likeCount: likeCount,
        viewerLiked: viewerLiked,
      );

  group('a comment carries its own like', () {
    test('every comment starts with a count, not a null', () {
      // "Every comment or reply has to have a like count" — zero, never absent,
      // so a row can always draw a heart without checking whether it may.
      expect(comment().likeCount, 0);
      expect(comment().viewerLiked, isFalse);
    });

    test('liking moves the count up and lights the heart', () {
      final liked = comment().copyWith(likeCount: 1, viewerLiked: true);

      expect(liked.likeCount, 1);
      expect(liked.viewerLiked, isTrue);
    });

    test('unliking moves it back down and puts the heart out', () {
      final unliked = comment(likeCount: 1, viewerLiked: true)
          .copyWith(likeCount: 0, viewerLiked: false);

      expect(unliked.likeCount, 0);
      expect(unliked.viewerLiked, isFalse);
    });

    test('someone else liking raises the count without lighting my heart', () {
      // The count is everyone's; the heart is mine. Conflating them lights
      // every reader's heart the moment one person taps.
      final other = comment().copyWith(likeCount: 1);

      expect(other.likeCount, 1);
      expect(other.viewerLiked, isFalse);
    });
  });

  group('the like survives being written down and read back', () {
    test('it round-trips through json', () {
      final json = comment(likeCount: 3, viewerLiked: true).toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.likeCount, 3);
      expect(restored.viewerLiked, isTrue);
    });

    test('it uses the keys the server sends', () {
      // snake_case on the wire. Parsing `likeCount` instead would read every
      // comment back as unliked, which is the same symptom by another route.
      final restored = ChatMessage.fromJson({
        'id': 'c1',
        'room_id': 'r1',
        'sender_id': 'u2',
        'sender_role': 'user',
        'content': 'what a shot',
        'created_at': DateTime.utc(2026, 9, 16).toIso8601String(),
        'like_count': 4,
        'viewer_liked': true,
      });

      expect(restored.likeCount, 4);
      expect(restored.viewerLiked, isTrue);
    });

    test('a payload with no like fields reads as unliked, not as a crash', () {
      // Rows written before the cache had the columns, and any older server.
      final restored = ChatMessage.fromJson({
        'id': 'c1',
        'room_id': 'r1',
        'sender_id': 'u2',
        'sender_role': 'user',
        'content': 'what a shot',
        'created_at': DateTime.utc(2026, 9, 16).toIso8601String(),
      });

      expect(restored.likeCount, 0);
      expect(restored.viewerLiked, isFalse);
    });

    test('copyWith leaves the like alone when it is not the subject', () {
      // The bug in miniature: the message is rewritten for some other reason —
      // an edit, a receipt — and the like must not be dropped on the way.
      final edited =
          comment(likeCount: 2, viewerLiked: true).copyWith(content: 'edited');

      expect(edited.content, 'edited');
      expect(edited.likeCount, 2);
      expect(edited.viewerLiked, isTrue);
    });
  });
}
