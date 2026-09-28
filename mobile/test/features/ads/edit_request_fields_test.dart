import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';

/// Everything a posted request holds is something it can be edited to.
///
/// The edit sheet collected six fields while the form that creates a request
/// collected ten, and the server's PATCH had always accepted all ten. The four
/// it dropped were the event date, the start time, the coverage and the budget
/// as a range — so a postponed shoot, a changed start, or a job that grew from
/// half a day to a full one meant deleting the request and posting it again,
/// losing its answers with it.
///
/// The date was the worst of them. The card leads on it, the board filters on
/// it, and the premium delivery promise is measured from it.
void main() {
  Map<String, dynamic> request({
    String? eventDate,
    String? eventTime,
    String? coverageKind,
    int? coverageHours,
    String? coverageNote,
    num? budgetMin,
    num? budgetMax,
  }) =>
      {
        'id': 'r1',
        'requester_id': 'u1',
        'requester_name': 'Ama',
        'requester_type': 'client',
        'title': 'Wedding at Labadi',
        'description': 'Full day',
        'event_type': 'wedding',
        'location': 'Accra',
        if (eventDate != null) 'event_date': eventDate,
        if (eventTime != null) 'event_time': eventTime,
        if (coverageKind != null) 'coverage_kind': coverageKind,
        if (coverageHours != null) 'coverage_hours': coverageHours,
        if (coverageNote != null) 'coverage_note': coverageNote,
        if (budgetMin != null) 'budget_min': budgetMin,
        if (budgetMax != null) 'budget_max': budgetMax,
      };

  group('the sheet can be seeded from what was posted', () {
    // Every field the sheet reopens has to survive the trip back from the
    // server, or the form silently starts blank and saves that blankness over
    // what was there.

    test('the event date comes back', () {
      final parsed = FeedRequestModel.fromJson(request(eventDate: '2026-09-10'));
      expect(parsed.eventDate, isNotNull);
      expect(parsed.eventDate!.day, 10);
      expect(parsed.eventDate!.month, 9);
    });

    test('the start time comes back as the server stores it', () {
      // "HH:MM" at the venue, deliberately not a timestamp — see AdRequest on
      // the server for why a wall-clock time is not an instant.
      expect(FeedRequestModel.fromJson(request(eventTime: '14:30')).eventTime,
          '14:30');
    });

    test('hourly coverage keeps its hours', () {
      final parsed = FeedRequestModel.fromJson(
        request(coverageKind: 'hourly', coverageHours: 3),
      );
      expect(parsed.coverageKind, 'hourly');
      expect(parsed.coverageHours, 3);
    });

    test('other coverage keeps its note', () {
      final parsed = FeedRequestModel.fromJson(
        request(coverageKind: 'other', coverageNote: 'Ceremony only'),
      );
      expect(parsed.coverageKind, 'other');
      expect(parsed.coverageNote, 'Ceremony only');
    });

    test('the budget comes back as the range it was asked as', () {
      // The sheet used to hold one figure, which could only ever write the
      // midpoint back over a range somebody had actually set.
      final parsed = FeedRequestModel.fromJson(
        request(budgetMin: 1000, budgetMax: 2500),
      );
      expect(parsed.budgetMin, 1000);
      expect(parsed.budgetMax, 2500);
    });

    test('a request with none of them set does not fail to open', () {
      // Every one of these is optional on a request and always has been.
      final parsed = FeedRequestModel.fromJson(request());
      expect(parsed.eventDate, isNull);
      expect(parsed.eventTime, isNull);
      expect(parsed.coverageKind, isNull);
      expect(parsed.budgetMin, isNull);
    });
  });

  group('reading the time back for a picker', () {
    // Mirrors `_parseTime` on the sheet, which is private. Null on anything
    // unparseable rather than throwing: an odd value on one request should
    // leave that field empty, not stop the sheet opening at all.
    ({int h, int m})? parse(String? wire) {
      if (wire == null || wire.isEmpty) return null;
      final parts = wire.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || h > 23 || m > 59) return null;
      return (h: h, m: m);
    }

    test('a normal time reads back', () {
      expect(parse('14:30'), (h: 14, m: 30));
    });

    test('midnight reads back, rather than reading as unset', () {
      expect(parse('00:00'), (h: 0, m: 0));
    });

    test('nonsense leaves the field empty instead of throwing', () {
      for (final bad in ['', 'noon', '25:00', '12:99', '12', '12:30:45']) {
        expect(parse(bad), isNull, reason: bad);
      }
    });
  });
}
