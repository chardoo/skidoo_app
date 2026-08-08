import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/api/dio_client_service.dart';

String _jwt(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(claims)}.sig';
}

int _epoch(Duration d) =>
    DateTime.now().toUtc().add(d).millisecondsSinceEpoch ~/ 1000;

void main() {
  group('a 401 only ends the session when the token itself has expired', () {
    test('expired token → session is over', () {
      expect(isJwtExpiredForTest(_jwt({'exp': _epoch(const Duration(hours: -1))})),
          isTrue);
    });

    test('valid token → session kept (a role-scoped 401 must not log out)', () {
      expect(isJwtExpiredForTest(_jwt({'exp': _epoch(const Duration(hours: 24))})),
          isFalse);
    });

    test('no exp claim → not our call, keep the session', () {
      expect(isJwtExpiredForTest(_jwt({'userId': 'abc'})), isFalse);
    });

    test('malformed token → keep the session rather than guess', () {
      for (final t in ['', 'nonsense', 'a.b', 'a.!!!not-base64!!!.c']) {
        expect(isJwtExpiredForTest(t), isFalse, reason: 'input: "$t"');
      }
    });
  });
}
