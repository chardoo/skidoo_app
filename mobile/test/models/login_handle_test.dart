/// Which field the login response's handle comes out of.
///
/// The payload carries two and they are different columns. `username` is the
/// public handle, generated at signup — `sarajohnson4821`. `uniqueName` is
/// `User.uiqueName`, the face-recognition person id, which for every account
/// that did not sign up as a photographer **is their email address**.
///
/// Reading the wrong one put an email under the avatar, and — because Edit
/// Profile prefills its Username field from the same value — made saving that
/// form impossible without touching the field: the API accepts a handle only
/// as `[A-Za-z0-9_]{3,30}`, and an address is neither.
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/models/Auth/LoginResponse.dart';

Map<String, dynamic> _payload({
  String? username,
  String? uniqueName,
  String? uiqueName,
}) =>
    {
      'id': 'u1',
      'email': 'sara@example.com',
      'name': 'Sara Johnson',
      'role': 'user',
      if (username != null) 'username': username,
      if (uniqueName != null) 'uniqueName': uniqueName,
      if (uiqueName != null) 'uiqueName': uiqueName,
      'token': 't',
      'expiration': '2026-01-01',
      'isValid': true,
    };

void main() {
  test('the handle comes from username, not from uniqueName', () {
    // Exactly the shape the server sends: both keys, uniqueName holding the
    // address because that is what uiqueName is for an ordinary account.
    final user = LoginResponseObject.fromJson(_payload(
      username: 'sarajohnson4821',
      uniqueName: 'sara@example.com',
    ));

    expect(user.uniqueName, 'sarajohnson4821');
    expect(user.uniqueName, isNot(contains('@')));
  });

  test('falls back to uniqueName for a server without the column', () {
    final user =
        LoginResponseObject.fromJson(_payload(uniqueName: 'legacyhandle'));
    expect(user.uniqueName, 'legacyhandle');
  });

  test('falls back to the misspelled key a session file may hold', () {
    final user =
        LoginResponseObject.fromJson(_payload(uiqueName: 'olderhandle'));
    expect(user.uniqueName, 'olderhandle');
  });

  test('neither key is empty rather than a crash', () {
    expect(LoginResponseObject.fromJson(_payload()).uniqueName, '');
  });

  test('a session survives a round trip through its own json', () {
    // toJson used to write `uiqueName` while fromJson read `uniqueName`, so
    // the handle vanished on the way back in.
    final user = LoginResponseObject.fromJson(_payload(
      username: 'sarajohnson4821',
      uniqueName: 'sara@example.com',
    ));

    final again = LoginResponseObject.fromJson(user.toJson());
    expect(again.uniqueName, 'sarajohnson4821');
  });
}
