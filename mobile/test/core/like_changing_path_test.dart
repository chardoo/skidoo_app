import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/api/dio_client_service.dart';

/// Which requests mean "what this person has liked just changed".
///
/// The profile's Liked tab keeps its grid for the session and refetches only
/// when `AppCacheSignals.likes` moves, so this matcher is the only thing that
/// puts a like on that screen without restarting the app. It had been forgotten
/// three separate times — the comment sheet's heart and both of the chat room's
/// recorded real likes and told nothing — which is why the rule moved into the
/// one place every HTTP like has to pass through, and why it is held to it here.
///
/// Too narrow and "my like is not in my likes" comes back. Too generous and
/// every liked grid refetches on requests that changed nothing.
void main() {
  group('requests that change what is liked', () {
    test('toggling a photo', () {
      expect(changesLikesForTest('POST', '/chat/pictures/abc-123/like'), isTrue);
    });

    test('removing a photo like outright', () {
      expect(
        changesLikesForTest('DELETE', '/chat/pictures/abc-123/like'),
        isTrue,
      );
    });

    test('setting a reaction on an album', () {
      expect(changesLikesForTest('POST', '/chat/events/abc-123/reaction'), isTrue);
    });

    test('clearing it — the same path with no reaction named', () {
      expect(
        changesLikesForTest('POST', '/chat/events/abc-123/reaction?reaction='),
        isTrue,
      );
    });

    test('a caller that built the path with the /api prefix on it', () {
      expect(
        changesLikesForTest('POST', '/api/chat/pictures/abc-123/like'),
        isTrue,
      );
    });

    test('an absolute URL is matched on its path', () {
      expect(
        changesLikesForTest(
          'POST',
          'https://api.example.com/chat/pictures/x1/like',
        ),
        isTrue,
      );
    });

    test('a lower-case method still counts', () {
      expect(changesLikesForTest('post', '/chat/pictures/abc-123/like'), isTrue);
    });
  });

  group('requests that do not', () {
    test('reading a photo like state', () {
      // The grid would refetch on every card that asks who liked what.
      expect(changesLikesForTest('GET', '/chat/pictures/abc-123/like'), isFalse);
    });

    test('reading an album reaction', () {
      expect(
        changesLikesForTest('GET', '/chat/events/abc-123/reaction?userId=u1'),
        isFalse,
      );
    });

    test('liking a comment, which is not a liked *thing*', () {
      // Comment likes live on the comment, not on the Liked grid.
      expect(
        changesLikesForTest('POST', '/chat/comments/abc-123/like'),
        isFalse,
      );
    });

    test('a campaign like, which the Liked grid does not list', () {
      expect(
        changesLikesForTest('POST', '/chat/assets/campaign/abc-123/like'),
        isFalse,
      );
    });

    test('bookmarking — a different grid and a different signal', () {
      expect(changesLikesForTest('POST', '/client/u1/saved'), isFalse);
    });

    test('a longer path that merely starts the same way', () {
      expect(
        changesLikesForTest('POST', '/chat/pictures/abc-123/like/extra'),
        isFalse,
      );
    });

    test('the empty path', () {
      expect(changesLikesForTest('POST', ''), isFalse);
    });
  });
}
