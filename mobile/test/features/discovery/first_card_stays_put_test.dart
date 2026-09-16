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
EventDiscovery event(String id) => EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'Creator',
      photographerId: 'c1',
      pictures: const [],
    );

List<String> ids(List<EventDiscovery> events) =>
    events.map((e) => e.id).toList();

void main() {
  group('opening the app', () {
    test('the cached first card stays first when the fetch lands', () {
      // The bug, exactly: cache shows 'a', the server now ranks it third.
      final fresh = [event('b'), event('c'), event('a'), event('d')];

      expect(
        ids(DiscoveryBloc.keepFirst(fresh, onScreen: 'a')),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('everything else keeps the fresh order behind it', () {
      // The rotation still happens — it just does not reach the one post the
      // reader is looking at.
      final fresh = [event('d'), event('c'), event('b'), event('a')];

      expect(
        ids(DiscoveryBloc.keepFirst(fresh, onScreen: 'a')),
        ['a', 'd', 'c', 'b'],
      );
    });

    test('nothing moves when the server already agrees', () {
      final fresh = [event('a'), event('b')];

      expect(DiscoveryBloc.keepFirst(fresh, onScreen: 'a'), same(fresh));
    });

    test('a post that is gone is not pinned', () {
      // Hidden, deleted, or simply out of the ranking — there is nothing to
      // pin, and inventing a row for it would put a dead card on top.
      final fresh = [event('b'), event('c')];

      expect(ids(DiscoveryBloc.keepFirst(fresh, onScreen: 'a')), ['b', 'c']);
    });

    test('an empty fetch is left alone', () {
      expect(DiscoveryBloc.keepFirst(const [], onScreen: 'a'), isEmpty);
    });

    test('nothing on screen yet means nothing to protect', () {
      // A cold start with an empty cache: the first thing the reader sees is
      // the server's own order, which is what it should be.
      final fresh = [event('b'), event('a')];

      expect(DiscoveryBloc.keepFirst(fresh, onScreen: null), same(fresh));
    });

    test('no post is duplicated by the pin', () {
      final fresh = [event('b'), event('a'), event('c')];

      final result = ids(DiscoveryBloc.keepFirst(fresh, onScreen: 'a'));

      expect(result, ['a', 'b', 'c']);
      expect(result.toSet().length, result.length);
    });
  });
}
