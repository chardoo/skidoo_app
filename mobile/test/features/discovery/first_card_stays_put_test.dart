import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The post you open the app to does not slide away under your thumb.
///
/// The feed paints from cache the instant the app opens, then replaces that
/// with the server's answer a second or two later. Those two lists used to
/// agree — the ranking was deterministic, so the replacement was invisible.
///
/// It is not deterministic any more. The top of the feed rotates on purpose
/// now, and the impression log demotes whatever led the last rebuild. The card
/// restored from cache *is* whatever led last time, which makes it precisely
/// the one the server will move — so the first card changed on essentially
/// every launch. The rotation is wanted; having it applied to the post already
/// on screen is not.
///
/// A pull to refresh is the opposite: an explicit request for a new deal, and
/// nothing is pinned there.
EventDiscovery event(String id, {List<String> pics = const []}) =>
    EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'Creator',
      photographerId: 'c1',
      pictures: [for (final p in pics) pic(p)],
    );

EventPicture pic(String id, {double price = 1}) =>
    EventPicture(id: id, url: 'u/$id', imageId: 'i$id', price: price);

List<String> ids(List<EventDiscovery> events) =>
    events.map((e) => e.id).toList();

List<String> picIds(EventDiscovery e) => e.pictures.map((p) => p.id).toList();

void main() {
  group('opening the app', () {
    test('the cached first card stays first when the fetch lands', () {
      // The bug, exactly: cache shows 'a', the server now ranks it third.
      final fresh = [event('b'), event('c'), event('a'), event('d')];

      expect(
        ids(DiscoveryBloc.keepFirst(fresh, onScreen: event('a'))),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('everything else keeps the fresh order behind it', () {
      // The rotation still happens — it just does not reach the one post the
      // reader is looking at.
      final fresh = [event('d'), event('c'), event('b'), event('a')];

      expect(
        ids(DiscoveryBloc.keepFirst(fresh, onScreen: event('a'))),
        ['a', 'd', 'c', 'b'],
      );
    });

    test('nothing moves when the server already agrees', () {
      final fresh = [event('a'), event('b')];

      expect(DiscoveryBloc.keepFirst(fresh, onScreen: event('a')), same(fresh));
    });

    test('a post that is gone is not pinned', () {
      // Hidden, deleted, or simply out of the ranking — there is nothing to
      // pin, and inventing a row for it would put a dead card on top.
      final fresh = [event('b'), event('c')];

      expect(ids(DiscoveryBloc.keepFirst(fresh, onScreen: event('a'))), ['b', 'c']);
    });

    test('an empty fetch is left alone', () {
      expect(DiscoveryBloc.keepFirst(const [], onScreen: event('a')), isEmpty);
    });

    test('nothing on screen yet means nothing to protect', () {
      // A cold start with an empty cache: the first thing the reader sees is
      // the server's own order, which is what it should be.
      final fresh = [event('b'), event('a')];

      expect(DiscoveryBloc.keepFirst(fresh, onScreen: null), same(fresh));
    });

    test('no post is duplicated by the pin', () {
      final fresh = [event('b'), event('a'), event('c')];

      final result = ids(DiscoveryBloc.keepFirst(fresh, onScreen: event('a')));

      expect(result, ['a', 'b', 'c']);
      expect(result.toSet().length, result.length);
    });
  });

  /// Holding the post's slot turned out to be only half of it.
  ///
  /// The photos inside a card are dealt by the server too, seeded off the feed
  /// snapshot — and the first page of a feed rebuilds that snapshot every time
  /// it is asked for. So the pinned post came back with its pictures
  /// reshuffled while the card kept its widget key and its carousel index:
  /// same post, same slot, a different photograph a second after launch. Which
  /// to the reader is the complaint above, one level down.
  group('the photo on the pinned card', () {
    test('is still the photo that was on screen', () {
      final onScreen = event('a', pics: ['p3', 'p1', 'p2']);
      // The server re-dealt the feed *and* this album's pictures.
      final fresh = [event('b'), event('a', pics: ['p1', 'p2', 'p3'])];

      final result = DiscoveryBloc.keepFirst(fresh, onScreen: onScreen);

      expect(ids(result), ['a', 'b']);
      expect(picIds(result.first), ['p3', 'p1', 'p2']);
    });

    test('holds even when the post never moved', () {
      // The rotation left 'a' on top, so the slot itself never needed pinning
      // — but the pictures were re-dealt all the same, which is the symptom.
      final onScreen = event('a', pics: ['p3', 'p1', 'p2']);
      final fresh = [event('a', pics: ['p1', 'p2', 'p3']), event('b')];

      final result = DiscoveryBloc.keepFirst(fresh, onScreen: onScreen);

      expect(picIds(result.first), ['p3', 'p1', 'p2']);
    });

    test('is the fresh record, not the cached one', () {
      // Only the order is the reader's. A new price, a like counted, a comment
      // closed — all of that still lands.
      final onScreen = event('a', pics: ['p2', 'p1']);
      final fresh = [
        EventDiscovery(
          id: 'a',
          eventName: 'Event a',
          photographerName: 'Creator',
          photographerId: 'c1',
          pictures: [pic('p1', price: 9), pic('p2', price: 9)],
        ),
      ];

      final result = DiscoveryBloc.keepFirst(fresh, onScreen: onScreen);

      expect(picIds(result.first), ['p2', 'p1']);
      expect(result.first.pictures.map((p) => p.price), [9, 9]);
    });

    test('a photo added since is appended rather than dropped', () {
      final onScreen = event('a', pics: ['p2', 'p1']);
      final fresh = [event('a', pics: ['p1', 'p3', 'p2', 'p4'])];

      final result = DiscoveryBloc.keepFirst(fresh, onScreen: onScreen);

      // What was on screen keeps its arrangement; the new ones follow it in
      // the server's order.
      expect(picIds(result.first), ['p2', 'p1', 'p3', 'p4']);
    });

    test('a photo taken away simply goes', () {
      final onScreen = event('a', pics: ['p2', 'p1', 'p3']);
      final fresh = [event('a', pics: ['p1', 'p3'])];

      final result = DiscoveryBloc.keepFirst(fresh, onScreen: onScreen);

      expect(picIds(result.first), ['p1', 'p3']);
    });

    test('an album with nothing in common keeps the server order', () {
      final onScreen = event('a', pics: ['old1', 'old2']);
      final fresh = [event('a', pics: ['p1', 'p2'])];

      final result = DiscoveryBloc.keepFirst(fresh, onScreen: onScreen);

      expect(picIds(result.first), ['p1', 'p2']);
    });

    test('an order that already agrees rebuilds nothing', () {
      final fresh = [event('a', pics: ['p1', 'p2']), event('b')];

      expect(
        DiscoveryBloc.keepFirst(
          fresh,
          onScreen: event('a', pics: ['p1', 'p2']),
        ),
        same(fresh),
      );
    });
  });
}
