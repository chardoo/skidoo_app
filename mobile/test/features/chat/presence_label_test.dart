import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart'
    show PresenceSnapshot;
import 'package:jperg_app/features/chat/presentation/presence_label.dart';

/// What the line under somebody's name is allowed to claim.
///
/// The web version of this header said "Connected" while reporting only the
/// browser's own socket state — it asserted the other person was there on
/// evidence that said nothing about them. These pin the mobile one against the
/// same class of mistake: the label may only say what we actually know, and
/// "we have not been told" is a different thing from "offline".

final _now = DateTime.utc(2026, 8, 27, 12, 0);

PresenceSnapshot online() =>
    PresenceSnapshot(online: true, lastSeen: _now.subtract(const Duration(seconds: 5)));

PresenceSnapshot offlineSince(Duration ago) =>
    PresenceSnapshot(online: false, lastSeen: _now.subtract(ago));

void main() {
  group('presenceLabel', () {
    test('says Online when they are there', () {
      expect(presenceLabel(online(), now: _now), 'Online');
    });

    test('says nothing at all when nobody has told us', () {
      // The important one. An account we have no answer for is unknown, not
      // offline — rendering "Offline" would assert something we do not know,
      // which is exactly the bug being fixed on the web.
      expect(presenceLabel(null, now: _now), isNull);
    });

    test('says nothing when they are offline but never seen', () {
      // Same reasoning: an account that has never connected since presence
      // existed has no last-seen, and "Last seen never" is not a sentence.
      expect(
        presenceLabel(const PresenceSnapshot(online: false), now: _now),
        isNull,
      );
    });

    test('online outranks any last-seen we hold', () {
      // last_seen is stamped on every heartbeat, so it is always a moment old
      // even for somebody sitting in the app. Reading it first would show
      // "Last seen 0m ago" for a person who is demonstrably present.
      final stale = PresenceSnapshot(
        online: true,
        lastSeen: _now.subtract(const Duration(days: 3)),
      );
      expect(presenceLabel(stale, now: _now), 'Online');
    });

    test('reports when they were last here', () {
      expect(
        presenceLabel(offlineSince(const Duration(hours: 3)), now: _now),
        'Last seen 3h ago',
      );
    });
  });

  group('relativeTime', () {
    test('is coarse near zero', () {
      // Presence is renewed on a timer, so the figure is only good to within a
      // lease. "43 seconds ago" claims a precision this does not have.
      expect(relativeTime(_now.subtract(const Duration(seconds: 5)), now: _now),
          'just now');
      expect(relativeTime(_now.subtract(const Duration(seconds: 59)), now: _now),
          'just now');
    });

    test('counts minutes, then hours, then days', () {
      expect(relativeTime(_now.subtract(const Duration(minutes: 1)), now: _now),
          '1m ago');
      expect(relativeTime(_now.subtract(const Duration(minutes: 59)), now: _now),
          '59m ago');
      expect(relativeTime(_now.subtract(const Duration(hours: 1)), now: _now),
          '1h ago');
      expect(relativeTime(_now.subtract(const Duration(hours: 23)), now: _now),
          '23h ago');
      expect(relativeTime(_now.subtract(const Duration(days: 1)), now: _now),
          'yesterday');
      expect(relativeTime(_now.subtract(const Duration(days: 3)), now: _now),
          '3d ago');
    });

    test('falls back to a date past a week', () {
      expect(relativeTime(DateTime.utc(2026, 8, 4, 9), now: _now), '4 Aug');
    });

    test('a clock ahead of the server reads as just now, not the future', () {
      // Phone clocks drift. "In 3 minutes" reads as a bug, and there is no
      // useful thing to say about a last-seen that has not happened yet.
      expect(relativeTime(_now.add(const Duration(minutes: 3)), now: _now),
          'just now');
    });
  });
}
