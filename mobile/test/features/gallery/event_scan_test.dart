import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/gallery/data/event_scan.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The live scan behind a scanned or typed event code.
///
/// Why it exists at all: `/client/my-photos` reads stored identification rows,
/// and an event uploaded before the person had an account has none — their
/// face was not in the index when the upload worker ran. It answers "nothing
/// found", correctly, forever. This runs recognition now.
///
/// What is worth pinning here is the counting rule and the signalling, because
/// both are easy to get subtly wrong and neither shows up as a crash.

/// Feeds a canned SSE body to the scan.
class _FakeClient extends http.BaseClient {
  _FakeClient(this._lines, {this.status = 200});

  final List<String> _lines;
  final int status;
  final _controller = StreamController<List<int>>();

  http.BaseRequest? sent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent = request;
    // Emitted after the listener attaches, so nothing is missed.
    scheduleMicrotask(() async {
      for (final line in _lines) {
        _controller.add(utf8.encode('data: $line\n\n'));
        await Future<void>.delayed(Duration.zero);
      }
      await _controller.close();
    });
    return http.StreamedResponse(_controller.stream, status);
  }
}

String _match(String category, {String id = 'p1', String? eventName}) =>
    jsonEncode({
      'type': 'match',
      'category': category,
      'image': {
        'id': id,
        'url': 'https://x/$id.jpg',
        if (eventName != null) 'event': {'eventName': eventName},
      },
    });

const _done = '{"type":"done"}';

Future<void> _run(EventScan scan) async {
  await scan.start();
  // Let the canned stream drain.
  for (var i = 0; i < 50 && scan.isRunning.value; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() {
    if (!sl.isRegistered<Api>()) sl.registerSingleton<Api>(Api());
    if (!sl.isRegistered<AuthService>()) {
      sl.registerSingleton<AuthService>(AuthService());
    }
  });

  tearDown(() async {
    await sl.reset();
  });

  group('counting', () {
    test('counts photos of this person, not the whole event', () async {
      // An owner scanning their own event receives every picture in the
      // `public` bucket. Counting those would announce "247 photos of you
      // found" about somebody else's wedding.
      final scan = EventScan(
        code: 'CODE-1',
        httpClient: _FakeClient([
          _match('public', id: 'a'),
          _match('public', id: 'b'),
          _match('myImages', id: 'c'),
          _done,
        ]),
      );
      addTearDown(scan.dispose);

      await _run(scan);

      expect(scan.mineCount.value, 1);
    });

    test('counts batched matches too', () async {
      final scan = EventScan(
        code: 'CODE-1',
        httpClient: _FakeClient([
          jsonEncode({
            'type': 'match_batch',
            'category': 'myImages',
            'images': [
              {'id': 'a', 'url': 'https://x/a.jpg'},
              {'id': 'b', 'url': 'https://x/b.jpg'},
            ],
          }),
          _done,
        ]),
      );
      addTearDown(scan.dispose);

      await _run(scan);

      expect(scan.mineCount.value, 2);
    });

    test('an event with none of you counts zero and is not an error', () async {
      final scan = EventScan(
        code: 'CODE-1',
        httpClient: _FakeClient([_match('public'), _done]),
      );
      addTearDown(scan.dispose);

      await _run(scan);

      expect(scan.mineCount.value, 0);
      expect(scan.error.value, isNull);
      expect(scan.isRunning.value, isFalse);
    });
  });

  group('the request', () {
    test('never names whose face to look for', () async {
      // The server reads the person from the token and ignores a body value.
      // Sending one invites the next reader to believe it is honoured.
      final fake = _FakeClient([_done]);
      final scan = EventScan(code: 'CODE-1', httpClient: fake);
      addTearDown(scan.dispose);

      await _run(scan);

      final body = jsonDecode((fake.sent as http.Request).body) as Map;
      expect(body['eventId'], 'CODE-1');
      expect(body.containsKey('uiqueName'), isFalse);
    });

    test('sends the code untouched, id or access code alike', () async {
      // The server resolves either form; the app does not know which it has.
      final fake = _FakeClient([_done]);
      final scan = EventScan(code: 'praise-2026', httpClient: fake);
      addTearDown(scan.dispose);

      await _run(scan);

      expect(
        jsonDecode((fake.sent as http.Request).body)['eventId'],
        'praise-2026',
      );
    });
  });

  group('telling the album there is more', () {
    test('signals as matches arrive, not once per photo', () async {
      // The album refetches on this signal. One refetch per photo would put a
      // network request behind every tile.
      var bumps = 0;
      void onBump() => bumps++;
      AppCacheSignals.foundPhotos.addListener(onBump);
      addTearDown(() => AppCacheSignals.foundPhotos.removeListener(onBump));

      final scan = EventScan(
        code: 'CODE-1',
        httpClient: _FakeClient([
          for (var i = 0; i < 7; i++) _match('myImages', id: 'p$i'),
          _done,
        ]),
      );
      addTearDown(scan.dispose);

      await _run(scan);

      expect(scan.mineCount.value, 7);
      // Batched at 5, plus the tail flushed on done.
      expect(bumps, lessThan(7));
      expect(bumps, greaterThanOrEqualTo(1));
    });

    test('the tail is flushed when the stream ends', () async {
      // Fewer than a full batch still has to reach the album, or the last few
      // photos of every scan would be invisible until something else refetched.
      var bumps = 0;
      void onBump() => bumps++;
      AppCacheSignals.foundPhotos.addListener(onBump);
      addTearDown(() => AppCacheSignals.foundPhotos.removeListener(onBump));

      final scan = EventScan(
        code: 'CODE-1',
        httpClient: _FakeClient([_match('myImages'), _done]),
      );
      addTearDown(scan.dispose);

      await _run(scan);

      expect(bumps, 1);
    });
  });

  group('failure', () {
    test('a non-200 is an error', () async {
      final scan = EventScan(
        code: 'CODE-1',
        httpClient: _FakeClient([], status: 400),
      );
      addTearDown(scan.dispose);

      await _run(scan);

      expect(scan.error.value, isNotNull);
      expect(scan.isRunning.value, isFalse);
    });

    test('photos already found survive a stream that breaks late', () async {
      // Those rows are written server-side by the time they reach us. Throwing
      // the screen away over a dropped connection would discard a real result.
      final scan = EventScan(
        code: 'CODE-1',
        httpClient: _FakeClient([_match('myImages')]),
      );
      addTearDown(scan.dispose);

      await _run(scan);

      expect(scan.mineCount.value, 1);
      expect(scan.error.value, isNull);
    });
  });

  test('the event name is taken from the first photo that carries it', () async {
    // The result card names the album, and nothing else on that screen knows
    // it — the code the person typed is not a name.
    final scan = EventScan(
      code: 'CODE-1',
      httpClient: _FakeClient([
        _match('myImages', id: 'a', eventName: 'Praise Reloaded 2026'),
        _done,
      ]),
    );
    addTearDown(scan.dispose);

    await _run(scan);

    expect(scan.eventName.value, 'Praise Reloaded 2026');
  });

  test('cancel stops it without reporting a failure', () async {
    // Leaving the scan screen. A discarded scan should not keep spending
    // recognition calls, and it is not an error that nobody waited.
    final scan = EventScan(
      code: 'CODE-1',
      httpClient: _FakeClient([_match('myImages')]),
    );
    addTearDown(scan.dispose);

    await scan.start();
    scan.cancel();

    expect(scan.isRunning.value, isFalse);
    expect(scan.error.value, isNull);
  });
}
