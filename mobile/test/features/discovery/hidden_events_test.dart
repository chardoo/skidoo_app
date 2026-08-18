import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

EventDiscovery ev(String id) => EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'Ama',
      photographerId: 'p1',
      pictures: const [],
    );

List<String> idsOf(List<EventDiscovery> events) =>
    events.map((e) => e.id).toList();

void main() {
  group('withoutHidden', () {
    test('hidden events are dropped, the rest keep their order', () {
      final events = [ev('a'), ev('b'), ev('c'), ev('d')];
      expect(
        idsOf(DiscoveryBloc.withoutHidden(events, {'b', 'd'})),
        ['a', 'c'],
      );
    });

    test('a hidden event returned again by the server is still dropped', () {
      // The half of the bug that made hiding look temporary: the feed filtered
      // the list in front of you, then the next fetch put the event straight
      // back because nothing filtered what came in.
      final nextPage = [ev('c'), ev('hidden-one'), ev('e')];
      expect(
        idsOf(DiscoveryBloc.withoutHidden(nextPage, {'hidden-one'})),
        ['c', 'e'],
      );
    });

    test('nothing hidden returns the list untouched', () {
      final events = [ev('a'), ev('b')];
      expect(DiscoveryBloc.withoutHidden(events, const {}), same(events));
    });

    test('an id that is not in the list changes nothing', () {
      final events = [ev('a'), ev('b')];
      expect(idsOf(DiscoveryBloc.withoutHidden(events, {'zzz'})), ['a', 'b']);
    });

    test('hiding everything leaves an empty feed, not an error', () {
      expect(DiscoveryBloc.withoutHidden([ev('a')], {'a'}), isEmpty);
    });
  });
}
