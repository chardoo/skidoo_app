import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/logging/log_redaction.dart';

/// What may reach the device log.
///
/// `debugPrint` survives into a release build, and the repositories log whole
/// response bodies — so these are the lines that decide whether a session
/// token or somebody's email address ends up in a sysdiagnose.
void main() {
  group('credentials never appear', () {
    test('a bare JWT is replaced wherever it sits', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJhYmMifQ.'
          'c2lnbmF0dXJlLWhlcmU';
      final out = redactForLog('[Api] retrying with $jwt after 401');
      expect(out, contains('«jwt»'));
      expect(out, isNot(contains('eyJ')));
      expect(out, contains('after 401'), reason: 'the useful part survives');
    });

    test('an Authorization header keeps its label and loses its value', () {
      final out = redactForLog(
          '[Api] headers={Authorization: Bearer abc123def456ghi, '
          'Content-Type: application/json}');
      expect(out, contains('Bearer «redacted»'));
      expect(out, isNot(contains('abc123def456ghi')));
      expect(out, contains('application/json'));
    });

    test('a token in a query string or a body is replaced', () {
      expect(redactForLog('connecting to /chat/ws/me?token=abcd1234efgh'),
          contains('token=«redacted»'));
      expect(redactForLog('POST /login body={"password": "hunter2hunter"}'),
          isNot(contains('hunter2')));
    });

    test('an App Store receipt is not logged in full', () {
      final out = redactForLog(
          'settleIosBoost body={"signedTransaction": "aaaa.bbbb.cccc", '
          '"orderToken": "4f1c"}');
      expect(out, isNot(contains('aaaa.bbbb.cccc')));
      expect(out, contains('orderToken'),
          reason: 'the order token is a single-use nonce and worth keeping');
    });
  });

  group('personal detail never appears', () {
    test('email addresses go', () {
      final out = redactForLog(
          '[Profile] body={"email": "ama.mensah@example.com", "name": "Ama"}');
      expect(out, isNot(contains('ama.mensah')));
      expect(out, contains('«email»'));
    });

    test('phone numbers go, in the shapes this app sees', () {
      for (final phone in ['+233244123456', '0244 123 456', '+1 (555) 123-4567']) {
        expect(redactForLog('phone=$phone'), isNot(contains('123')),
            reason: '$phone should not survive');
      }
    });

    test('ids are not mistaken for phone numbers', () {
      const id = '4f1c9a2e-7b35-4a1d-9c88-2e7f5b0a1d33';
      expect(redactForLog('request_id=$id'), contains(id));
      expect(redactForLog('status=200 count=12'), contains('count=12'));
    });

    test('numbers that are not phone numbers survive', () {
      // The first pass at this rule matched any long run of digits, which ate
      // byte counts, epoch timestamps and durations — and the diagnostics are
      // the reason this filter redacts instead of silencing.
      for (final line in [
        'imageCache maximumSizeBytes=104857600',
        'server time 1792364400000',
        '[Startup] DI ready — 1483ms',
        'boosted_until=2026-11-08T12:00:00Z',
      ]) {
        expect(redactForLog(line), line, reason: line);
      }
    });
  });

  group('long lines', () {
    final body = '[Ads] _unwrap — status: 200 body: ${'x' * 2000}';

    test('a release build cuts a dumped body and says by how much', () {
      final out = redactForLog(body, release: true);
      expect(out.length, lessThan(500));
      expect(out, contains('more chars»'));
      expect(out, startsWith('[Ads] _unwrap — status: 200'),
          reason: 'the status still has to be readable');
    });

    test('a debug build keeps the whole thing', () {
      expect(redactForLog(body, release: false).length,
          greaterThan(2000 - 100));
    });
  });

  test('nothing in, nothing out', () {
    expect(redactForLog(null), '');
    expect(redactForLog(''), '');
  });

  test('an ordinary diagnostic line is untouched', () {
    const line = '[IAP] cleared 2 unfinished transaction(s)';
    expect(redactForLog(line), line);
    const marker = '[Startup] build marker: deeplink-session-fixes-v1';
    expect(redactForLog(marker), marker);
  });
}
