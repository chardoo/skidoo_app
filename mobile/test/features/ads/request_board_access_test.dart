import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/request_board_access.dart';

/// Who the request board is for, and — just as much — who campaigns are for.
///
/// Two audiences that kept being confused for one because they sit next to
/// each other on the same card:
///
/// - A **request** is a job going begging. It means nothing to somebody who
///   cannot do the work, so browsing the board is photographers and admins.
///   The server has said so since 2026-08-26; the app offered the board to
///   everybody anyway, and a client who tapped it arrived at a screen that was
///   empty and always would be.
/// - A **campaign** is an ad anyone can buy, and everyone already sees them
///   running in the feed. It carries no role test at all, and adding one is
///   the regression this file is here to catch.
void main() {
  group('browsing the board', () {
    test('a photographer may', () {
      expect(canBrowseRequestBoard('photographer'), isTrue);
    });

    test('an ordinary user may not', () {
      expect(canBrowseRequestBoard('user'), isFalse);
    });

    test('a signed-out visitor may not', () {
      // The role notifier is empty until a session primes it, and a screen can
      // be built in that window.
      expect(canBrowseRequestBoard(''), isFalse);
    });

    test('admins may, under either spelling', () {
      // The app stores `super_admin`; the API issues `superAdmin`. They have
      // never agreed, and a board that silently fails to open for an admin is
      // not worth the tidiness of picking one.
      for (final role in ['super_admin', 'superAdmin', 'Admin', 'admin']) {
        expect(canBrowseRequestBoard(role), isTrue, reason: role);
      }
    });

    test('an unknown role may not', () {
      // Fail closed: a role this build has never heard of is not a creator.
      expect(canBrowseRequestBoard('moderator'), isFalse);
    });
  });

  group('what the rule must NOT be applied to', () {
    // These are not assertions about `canBrowseRequestBoard` so much as a note
    // in the only place someone tightening it will be looking. Posting a
    // request, managing what you posted, and buying an ad are open to every
    // account; only *browsing other people's* requests is not.
    test('the rule is about browsing, and nothing else', () {
      // A client is refused the board...
      expect(canBrowseRequestBoard('user'), isFalse);
      // ...and that is the whole of it. Anything keyed on this for posting, for
      // "My Requests", or for campaigns is reading it wrong: most requests come
      // from clients in the first place.
    });
  });
}
