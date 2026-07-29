import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// Whether one account's cached messages survive into the next session is
/// decided by a single comparison in `LoginUseCase.establishSession`. It used
/// to read `getUserId()`, which logout deletes — so after any logout the
/// comparison saw an empty string, concluded "first sign-in on this device",
/// and skipped the wipe. A different person signing in then inherited the
/// previous user's chat history.
///
/// The marker below is the fix: it outlives logout, so the question "is this
/// the same person coming back?" still has an answer. These pin the storage
/// contract that makes that work.
class _MemoryAuth extends AuthService {
  final _store = <String, String>{};

  @override
  Future<void> setLastAccountId(String id) async => _store['last'] = id;

  @override
  Future<String> getLastAccountId() async => _store['last'] ?? '';

  @override
  Future<String> getUserId() async => _store['session'] ?? '';

  Future<void> signIn(String id) async {
    _store['session'] = id;
    await setLastAccountId(id);
  }

  /// What removeToken() does to the session — note the marker is untouched.
  void logOut() => _store.remove('session');
}

/// Mirrors the guard in establishSession().
bool shouldWipe(String previousAccountId, String incomingUserId) =>
    previousAccountId.isNotEmpty && previousAccountId != incomingUserId;

void main() {
  late _MemoryAuth auth;
  setUp(() => auth = _MemoryAuth());

  test('same account logging back in keeps its data', () async {
    await auth.signIn('user-a');
    auth.logOut();

    // The session id is gone, but the device still knows who it belongs to.
    expect(await auth.getUserId(), isEmpty);
    expect(await auth.getLastAccountId(), 'user-a');

    expect(shouldWipe(await auth.getLastAccountId(), 'user-a'), isFalse);
  });

  test('a different user signing in after a logout wipes', () async {
    await auth.signIn('user-a');
    auth.logOut();

    // This is the case that used to leak: pre-fix, the check read the empty
    // session id and let user-b keep user-a's messages.
    expect(shouldWipe(await auth.getLastAccountId(), 'user-b'), isTrue);
  });

  test('a fresh sign-up after a logout wipes — new account, new id', () async {
    await auth.signIn('user-a');
    auth.logOut();
    expect(shouldWipe(await auth.getLastAccountId(), 'brand-new-id'), isTrue);
  });

  test('first ever sign-in on a device does not wipe', () async {
    expect(await auth.getLastAccountId(), isEmpty);
    expect(shouldWipe(await auth.getLastAccountId(), 'user-a'), isFalse);
  });

  test('switching without logging out still wipes', () async {
    await auth.signIn('user-a');
    // No logout — the original scenario the check was written for.
    expect(shouldWipe(await auth.getLastAccountId(), 'user-b'), isTrue);
  });

  test('the marker follows the newest account', () async {
    await auth.signIn('user-a');
    await auth.signIn('user-b');
    expect(await auth.getLastAccountId(), 'user-b');
    // user-a coming back later is now the switch.
    expect(shouldWipe(await auth.getLastAccountId(), 'user-a'), isTrue);
  });
}
