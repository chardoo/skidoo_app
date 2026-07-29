import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/gallery/presentation/found/found_access.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// Which gate a user lands on is decided entirely by two stored values, and
/// getting the pair backwards is invisible until someone signs in and is asked
/// to sign in again. These pin the mapping.
class _FakeAuth extends AuthService {
  _FakeAuth({required this.token, required this.hasFaces});

  final String token;
  final bool hasFaces;

  @override
  Future<String> getToken() async => token;

  @override
  Future<bool> getHasAddedFaces() async => hasFaces;
}

void main() {
  void register(_FakeAuth auth) {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    sl.registerSingleton<AuthService>(auth);
  }

  tearDown(() {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
  });

  test('signed in + has_added_faces false → noFaceAdded, not signedOut',
      () async {
    // The case that matters: this user already has an account, so the panel
    // must ask only for a face — no "Already have an account? Sign in".
    register(_FakeAuth(token: 'jwt', hasFaces: false));
    expect(await resolveFoundAccess(), FoundAccess.noFaceAdded);
  });

  test('signed in + has_added_faces true → ready', () async {
    register(_FakeAuth(token: 'jwt', hasFaces: true));
    expect(await resolveFoundAccess(), FoundAccess.ready);
  });

  test('no token → signedOut, whatever the face flag says', () async {
    // A stale face flag from a previous account must not let a guest through.
    register(_FakeAuth(token: '', hasFaces: true));
    expect(await resolveFoundAccess(), FoundAccess.signedOut);
  });
}
