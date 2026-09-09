import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/api/dio_client_service.dart';

/// Which 404s mean "that album is gone".
///
/// A 404 on an event-scoped path is the only way the phone finds out a
/// photographer deleted an album — there is no push for it, and the server
/// simply stops returning it. That 404 evicts the album from the caches the
/// Home, Following and Found tabs restore from at launch.
///
/// Which makes this matcher the dangerous part. Too generous and an unrelated
/// 404 — a picture, a chat room, a photographer — throws away a live album from
/// someone's offline feed. Too narrow and the dead card survives every cold
/// start. So the patterns are an explicit list, and this is what holds them to
/// it.
void main() {
  group('paths that are about an album', () {
    test('the photo grid behind an event row', () {
      expect(
        eventIdInPathForTest('/client/events/abc-123/photos'),
        'abc-123',
      );
    });

    test('the view ping the feed fires on open', () {
      expect(eventIdInPathForTest('/recommend/abc-123/view'), 'abc-123');
    });

    test('an id that was percent-encoded on the way out comes back decoded', () {
      // The caller encodes it (`Uri.encodeComponent`), so the id read back out
      // has to be decoded or it will not match anything in the cache.
      expect(
        eventIdInPathForTest('/client/events/a%2Fb/photos'),
        'a/b',
      );
    });

    test('a query string does not stop it matching', () {
      expect(
        eventIdInPathForTest('/client/events/abc-123/photos?page=2'),
        'abc-123',
      );
    });

    test('an absolute URL is matched on its path', () {
      expect(
        eventIdInPathForTest('https://api.example.com/client/events/x1/photos'),
        'x1',
      );
    });
  });

  group('paths that are not', () {
    test('a chat room for an event', () {
      // 404s when nobody has posted in the album yet, which is the normal state
      // of a live album and says nothing about whether it exists.
      expect(eventIdInPathForTest('/chat/rooms/event/abc-123'), isNull);
    });

    test('a reaction on an event', () {
      expect(
        eventIdInPathForTest('/chat/events/abc-123/reaction'),
        isNull,
      );
    });

    test('a photographer', () {
      expect(eventIdInPathForTest('/client/photographers/abc-123'), isNull);
    });

    test('the event list itself', () {
      expect(eventIdInPathForTest('/client/events'), isNull);
    });

    test('a picture', () {
      expect(eventIdInPathForTest('/client/pictures/abc-123'), isNull);
    });

    test('a longer path that merely starts the same way', () {
      expect(
        eventIdInPathForTest('/client/events/abc-123/photos/extra'),
        isNull,
      );
    });

    test('the empty path', () {
      expect(eventIdInPathForTest(''), isNull);
    });
  });
}
