import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/session/view_reporter.dart';

/// What the feed tells the server it looked at.
///
/// The ranking's re-view penalty is keyed on when the viewer last saw an event,
/// and nothing in the app was ever reporting it — so `viewed_at` was null for
/// everything, the penalty was a no-op, and an album that scored highest stayed
/// the first card through every refresh. This is the thing that reports it, so
/// what it does and does not send is the part worth pinning.
class _Reports {
  final calls = <({String entityType, String entityId, int? dwellSeconds})>[];

  void record({
    required String entityType,
    required String entityId,
    int? dwellSeconds,
  }) =>
      calls.add((
        entityType: entityType,
        entityId: entityId,
        dwellSeconds: dwellSeconds
      ));
}

void main() {
  late _Reports reports;
  late DateTime clock;
  late ViewWatch watch;

  setUp(() {
    reports = _Reports();
    clock = DateTime(2026, 9, 5, 12);
    watch = ViewWatch(report: reports.record, now: () => clock);
  });

  void wait(Duration d) => clock = clock.add(d);

  test('a card that was looked at is reported when the reader moves on', () {
    watch.showing('e1');
    wait(const Duration(seconds: 8));
    watch.showing('e2');

    expect(reports.calls, hasLength(1));
    expect(reports.calls.single.entityId, 'e1');
    expect(reports.calls.single.entityType, 'event');
    expect(reports.calls.single.dwellSeconds, 8);
  });

  test('nothing is reported while the card is still on screen', () {
    // The dwell is not known until they leave, so there is nothing to send yet.
    watch.showing('e1');
    wait(const Duration(minutes: 1));

    expect(reports.calls, isEmpty);
  });

  test('a card flicked past is not a view', () {
    // Swiping down a feed must not mark every album on the way as seen — that
    // would demote them all out of the next ranking on the strength of a
    // thumbnail going by.
    watch.showing('e1');
    wait(const Duration(milliseconds: 300));
    watch.showing('e2');

    expect(reports.calls, isEmpty);
  });

  test('the same card twice running is one look, not two', () {
    // Feeds say this on every rebuild; restarting the clock there would report
    // a card over and over and inflate its view count.
    watch.showing('e1');
    wait(const Duration(seconds: 4));
    watch.showing('e1');
    wait(const Duration(seconds: 4));
    watch.showing(null);

    expect(reports.calls, hasLength(1));
    expect(reports.calls.single.dwellSeconds, 8);
  });

  test('a slot that is not an event ends the look', () {
    // An ad or a suggestions card: nothing is being watched, and the card
    // before it is finished.
    watch.showing('e1');
    wait(const Duration(seconds: 3));
    watch.showing(null);

    expect(reports.calls.single.entityId, 'e1');

    // And nothing is pending afterwards.
    wait(const Duration(seconds: 30));
    watch.hidden();
    expect(reports.calls, hasLength(1));
  });

  test('leaving the feed reports the card that was open', () {
    // dispose(). Without it the last card of every session goes unreported —
    // including the one somebody stayed on longest.
    watch.showing('e1');
    wait(const Duration(seconds: 20));
    watch.hidden();

    expect(reports.calls.single.entityId, 'e1');
    expect(reports.calls.single.dwellSeconds, 20);
  });

  test('a phone left on a card is capped, and still counts', () {
    watch.showing('e1');
    wait(const Duration(hours: 9));
    watch.hidden();

    expect(reports.calls.single.entityId, 'e1');
    expect(reports.calls.single.dwellSeconds, const Duration(minutes: 10).inSeconds);
  });

  test('an empty id is not a card', () {
    watch.showing('');
    wait(const Duration(seconds: 30));
    watch.hidden();

    expect(reports.calls, isEmpty);
  });
}
