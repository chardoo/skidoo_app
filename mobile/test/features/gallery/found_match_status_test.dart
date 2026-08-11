import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';

/// Which answers a Found query counts.
///
/// A scan lands on a screen that asks "which of these aren't you", and the
/// matches it is asking about are the unanswered ones. Filtered to confirmed —
/// which is right for the Found tab and wrong here — that screen asked its
/// question about an empty list, and a scan of an event full of someone's
/// photos reported none.
void main() {
  test('the default stays confirmed, and says so by saying nothing', () {
    expect(FoundFilters.none.status, FoundMatchStatus.confirmed);
    expect(
      FoundFilters.none.toQueryParameters().containsKey('status'),
      isFalse,
      reason: 'the default is the server default; sending it is noise',
    );
  });

  test('a review screen asks for both', () {
    const filters = FoundFilters(status: FoundMatchStatus.all);
    expect(filters.toQueryParameters()['status'], 'all');
  });

  test('pending alone is what is waiting on them', () {
    const filters = FoundFilters(status: FoundMatchStatus.pending);
    expect(filters.toQueryParameters()['status'], 'pending');
  });

  test('a scanned code rides in as an event id', () {
    // The QR carries the access code; the server resolves either form, so the
    // app does not have to know which one it just read off a poster.
    const filters = FoundFilters(
      eventIds: {'PRAISE26'},
      status: FoundMatchStatus.all,
    );
    final query = filters.toQueryParameters();
    expect(query['eventId'], ['PRAISE26']);
    expect(query['status'], 'all');
  });

  test('status is not counted as a filter the user set', () {
    const filters = FoundFilters(status: FoundMatchStatus.all);
    expect(filters.activeCount, 0,
        reason: 'the badge counts choices made in the sheet, not the screen');
  });

  test('two selections differing only in status are not the same query', () {
    const confirmed = FoundFilters(eventIds: {'e1'});
    const all = FoundFilters(eventIds: {'e1'}, status: FoundMatchStatus.all);
    expect(confirmed, isNot(all));
    expect(confirmed.hashCode, isNot(all.hashCode));
  });
}
