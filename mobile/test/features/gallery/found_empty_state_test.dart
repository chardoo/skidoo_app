import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_empty_state.dart';

/// The Found tab told a user with five waiting matches that it had not matched
/// them to any photo.
///
/// `GET /client/my-photos` defaults to `status=confirmed`, so an account whose
/// every match is still `pending` gets an empty album list. The tab treated
/// empty-and-unfiltered as "nothing found" and returned early — before the
/// review banner, which is the only route into the review page where a match
/// is confirmed. Confirming was the only way to fill the grid, and a filled
/// grid was the only way to reach the banner: a deadlock the person could not
/// break from inside the app.
///
/// It also contradicted itself. The orange dot on the tab is driven by the
/// same pending count, so the app advertised matches on one surface and denied
/// them on another — which is how it was reported.
void main() {
  group('foundEmptyState', () {
    test('nothing found and nothing pending is the scanning state', () {
      expect(
        foundEmptyState(hasAlbums: false, pendingCount: 0, filtersActive: false),
        FoundEmptyState.scanning,
      );
    });

    test('pending matches are never "we found nothing"', () {
      // The bug, exactly: five matches awaiting an answer, no confirmed
      // photos, no filters.
      expect(
        foundEmptyState(hasAlbums: false, pendingCount: 5, filtersActive: false),
        FoundEmptyState.awaitingReview,
      );
    });

    test('pending outranks the filter message', () {
      // A filter did not hide these — they are not in the grid because they
      // have not been confirmed. Offering "clear filters" would point at a
      // setting that is not the reason.
      expect(
        foundEmptyState(hasAlbums: false, pendingCount: 2, filtersActive: true),
        FoundEmptyState.awaitingReview,
      );
    });

    test('filters that exclude everything say so', () {
      expect(
        foundEmptyState(hasAlbums: false, pendingCount: 0, filtersActive: true),
        FoundEmptyState.filteredOut,
      );
    });

    test('a populated grid is not an empty state, whatever else is true', () {
      for (final pending in [0, 3]) {
        for (final filtered in [false, true]) {
          expect(
            foundEmptyState(
              hasAlbums: true,
              pendingCount: pending,
              filtersActive: filtered,
            ),
            FoundEmptyState.none,
            reason: 'pending=$pending filtered=$filtered',
          );
        }
      }
    });

    test('the review banner shows whenever anything is pending', () {
      // The banner's visibility is the property that matters: it is the only
      // way to answer a match. Every state except `scanning` renders the full
      // page, and the banner draws itself when pending is non-empty.
      for (final filtered in [false, true]) {
        expect(
          foundEmptyState(
            hasAlbums: false,
            pendingCount: 1,
            filtersActive: filtered,
          ),
          isNot(FoundEmptyState.scanning),
          reason: 'the scanning state returns before the banner is built',
        );
      }
    });
  });
}
