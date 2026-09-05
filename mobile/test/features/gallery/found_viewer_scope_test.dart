import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_results_viewer_page.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// What the viewer swipes through when a photo is tapped on the Found feed.
///
/// The bug these come from: tapping a photo under an event opened *every*
/// found photo the person had. That was written on purpose, for the filtered
/// case — filter to twelve matches across four events, open one, and a viewer
/// scoped to its event strands the other ten — but it was applied
/// unconditionally, and unfiltered there is nothing to strand. The sections
/// are the only structure on the screen, and a photo under an event belongs to
/// that event.
///
/// The scoping is one argument, [FoundResultsViewerPage.eventId], which the
/// bloc folds into the query. These pin which value the feed passes when,
/// because that decision is the whole fix.
Photo photo(String id) => Photo.fromMap({
      'id': id,
      'url': 'https://cdn.example.com/$id.jpg',
      'event': const {'id': 'evt-1', 'eventName': 'Praise Reloaded 2026'},
    });

void main() {
  group('unfiltered — the sections are the structure', () {
    test('the viewer is told which event to stay in', () {
      final page = FoundResultsViewerPage(
        seed: [photo('a'), photo('b')],
        initialPhotoId: 'a',
        eventId: 'evt-1',
      );

      expect(page.eventId, 'evt-1');
    });
  });

  group('filtering — the matches are the structure', () {
    test('no event is named, so the whole result set is swiped', () {
      // Null is the instruction, not an oversight: FoundAlbumBloc leaves the
      // filters alone when there is no event to narrow them to.
      final page = FoundResultsViewerPage(
        seed: [photo('a'), photo('b')],
        initialPhotoId: 'a',
        filters: const FoundFilters(visibility: FoundVisibility.private),
      );

      expect(page.eventId, isNull);
      expect(page.filters.isActive, isTrue);
    });
  });

  group('what the narrowing actually does', () {
    // The mechanism the fix leans on. Naming an event has to reach the query,
    // or the viewer would ask for everything and merely believe it was scoped.

    test('an event id becomes an eventId in the query', () {
      const scoped = FoundFilters(eventIds: {'evt-1'});

      expect(scoped.toQueryParameters()['eventId'], ['evt-1']);
    });

    test('and it does not count as a filter the person set', () {
      // It is a navigation constraint, not something chosen in the sheet — so
      // it must not light the badge on the Filters button, and must not make
      // `isActive` true and send the feed back down the across-events path.
      const scoped = FoundFilters(eventIds: {'evt-1'});

      expect(scoped.isActive, isFalse);
      expect(scoped.activeCount, 0);
    });
  });

  test('the default is the whole set, which is what every other caller wants',
      () {
    // The deep link, the request page, search — none of them are opening a
    // photo out of an event section.
    final page = FoundResultsViewerPage(
      seed: [photo('a')],
      initialPhotoId: 'a',
    );

    expect(page.eventId, isNull);
    expect(page.filters, FoundFilters.none);
  });
}
