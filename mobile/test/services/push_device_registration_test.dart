/// When the device gets handed to our backend again.
///
/// The backend learns *which account* a device belongs to from the JWT on the
/// request, not from the body — so the same player id posted under a different
/// token means something different, and skipping the post because the body
/// would be identical is how an account ends up registered to nobody.
///
/// That was the bug: the guard compared the subscription id alone, and a
/// subscription id belongs to the device. Sign out, sign in as somebody else,
/// and it still matched — so the arriving account was never registered, while
/// the account that left stayed mapped to the phone.
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/services/push_notification_service_io.dart';

void main() {
  group('shouldRegisterDevice', () {
    test('a device never registered is registered', () {
      expect(
        shouldRegisterDevice(
          playerId: 'player-x',
          userId: 'user-a',
          registeredPlayerId: null,
          registeredUserId: null,
        ),
        isTrue,
      );
    });

    test('the same account on the same device is left alone', () {
      // The observer fires on every subscription change, not just the first,
      // so this is the common case and it must stay cheap.
      expect(
        shouldRegisterDevice(
          playerId: 'player-x',
          userId: 'user-a',
          registeredPlayerId: 'player-x',
          registeredUserId: 'user-a',
        ),
        isFalse,
      );
    });

    test('a new account on the same device is registered again', () {
      // The defect, stated directly: the player id is unchanged because the
      // device is unchanged, and the registration still has to happen.
      expect(
        shouldRegisterDevice(
          playerId: 'player-x',
          userId: 'user-b',
          registeredPlayerId: 'player-x',
          registeredUserId: 'user-a',
        ),
        isTrue,
      );
    });

    test('a new subscription for the same account is registered again', () {
      // The other half, which the old guard did get right: a reinstall or a
      // permission revoked and re-granted mints a new subscription id.
      expect(
        shouldRegisterDevice(
          playerId: 'player-y',
          userId: 'user-a',
          registeredPlayerId: 'player-x',
          registeredUserId: 'user-a',
        ),
        isTrue,
      );
    });

    test('signing in after a logout registers, even on the same device', () {
      // Logout clears both halves, so this is really "never registered" — but
      // it is the sequence people actually perform, and it is worth pinning
      // that clearing one and not the other cannot bring the skip back.
      expect(
        shouldRegisterDevice(
          playerId: 'player-x',
          userId: 'user-b',
          registeredPlayerId: null,
          registeredUserId: null,
        ),
        isTrue,
      );
    });

    test('no subscription id yet means nothing to register', () {
      // The id does not exist until the device has registered with APNs/FCM,
      // which happens after permission is granted — so this is every call made
      // before the person has answered the dialog.
      for (final id in <String?>[null, '']) {
        expect(
          shouldRegisterDevice(
            playerId: id,
            userId: 'user-a',
            registeredPlayerId: null,
            registeredUserId: null,
          ),
          isFalse,
          reason: 'playerId=${id == null ? 'null' : '""'}',
        );
      }
    });

    test('an unattached device is not posted twice', () {
      // Signed out, with the subscription already handed over for nobody.
      // Worth stating because null is a legitimate value for the account here,
      // not a missing one, and `!=` has to treat it as such.
      expect(
        shouldRegisterDevice(
          playerId: 'player-x',
          userId: null,
          registeredPlayerId: 'player-x',
          registeredUserId: null,
        ),
        isFalse,
      );
    });
  });
}
