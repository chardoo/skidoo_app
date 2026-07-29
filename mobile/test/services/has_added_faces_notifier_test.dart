import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/gallery/presentation/found/found_access.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// `has_added_faces` is written from the account page (delete face data) and
/// read by the Found tab, which lives in a keep-alive IndexedStack far from
/// it. The notifier is what connects the two; without it the tab keeps showing
/// matches for a face the server no longer has until the next app launch.
class _FakeAuth extends AuthService {
  _FakeAuth({bool hasFaces = false}) : _hasFaces = hasFaces;

  bool _hasFaces;

  // Signed in throughout — this is about the face flag, not the token.
  @override
  Future<String> getToken() async => 'jwt';

  @override
  Future<bool> getHasAddedFaces() async => _hasFaces;

  @override
  Future<void> setHasAddedFaces(bool v) async {
    _hasFaces = v;
    AuthService.hasAddedFaces.value = v;
  }
}

void main() {
  setUp(() {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
  });

  tearDown(() {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    AuthService.hasAddedFaces.value = false;
  });

  test('deleting face data flips the flag and notifies listeners', () async {
    final auth = _FakeAuth(hasFaces: true);
    sl.registerSingleton<AuthService>(auth);
    AuthService.hasAddedFaces.value = true;

    var notifications = 0;
    void listener() => notifications++;
    AuthService.hasAddedFaces.addListener(listener);
    addTearDown(() => AuthService.hasAddedFaces.removeListener(listener));

    // Access is granted while a face is on file.
    expect(await resolveFoundAccess(), FoundAccess.ready);

    // What the delete-face-data success path does.
    await auth.setHasAddedFaces(false);

    expect(AuthService.hasAddedFaces.value, isFalse);
    expect(notifications, 1, reason: 'the Found tab re-checks off this');

    // And the gate now asks for a face rather than showing matches.
    expect(await resolveFoundAccess(), FoundAccess.noFaceAdded);
  });

  test('re-adding a face flips it back', () async {
    final auth = _FakeAuth(hasFaces: false);
    sl.registerSingleton<AuthService>(auth);

    expect(await resolveFoundAccess(), FoundAccess.noFaceAdded);
    await auth.setHasAddedFaces(true);
    expect(AuthService.hasAddedFaces.value, isTrue);
    expect(await resolveFoundAccess(), FoundAccess.ready);
  });

  test('the notifier is a ValueListenable the UI can bind to', () {
    expect(AuthService.hasAddedFaces, isA<ValueListenable<bool>>());
  });
}
