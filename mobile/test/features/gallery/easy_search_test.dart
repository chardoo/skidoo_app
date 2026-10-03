import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/gallery/data/easy_search.dart';
import 'package:jperg_app/features/gallery/data/event_scan.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Easy search — the same answer as the enrolled scan, for someone who will not
/// leave a face behind.
///
/// What is worth pinning: the selfies really travel with the request (the whole
/// premise is that the server has nothing stored to look them up by), and the
/// envelope is read the same way the enrolled scan reads it, because the result
/// screen drives both through [LiveSearch] and cannot tell them apart.

class _FakeClient extends http.BaseClient {
  _FakeClient(this._lines, {this.status = 200});

  final List<String> _lines;
  final int status;
  final _controller = StreamController<List<int>>();

  http.BaseRequest? sent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent = request;
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

List<({String name, Uint8List bytes})> _faces(int n) => [
      for (var i = 0; i < n; i++)
        (name: 'selfie_$i.jpg', bytes: Uint8List.fromList([0xFF, 0xD8, i])),
    ];

Future<void> _run(EasySearch search) async {
  await search.start();
  for (var i = 0; i < 50 && search.isRunning.value; i++) {
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

  group('the request', () {
    test('carries the selfies and the code', () async {
      // The premise of the feature: with nothing enrolled, the only way the
      // server can know who to look for is the photos attached right here.
      final client = _FakeClient([_done]);
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(3),
        httpClient: client,
      );
      addTearDown(search.dispose);

      await _run(search);

      final sent = client.sent;
      expect(sent, isA<http.MultipartRequest>());
      final request = sent! as http.MultipartRequest;
      expect(request.fields['eventCode'], 'CODE-1');
      expect(request.files.map((f) => f.field), everyElement('faces'));
      expect(request.files.length, 3);
    });

    test('goes to easy-search, not the enrolled scan', () async {
      final client = _FakeClient([_done]);
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: client,
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(client.sent!.url.path, endsWith('/client/easy-search'));
    });

    test('asks for an event stream', () async {
      final client = _FakeClient([_done]);
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: client,
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(client.sent!.headers['Accept'], 'text/event-stream');
    });

    test('never names the person — that comes from the token', () async {
      // A person id the request could name is a person id it could name for
      // somebody else.
      final client = _FakeClient([_done]);
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: client,
      );
      addTearDown(search.dispose);

      await _run(search);

      final request = client.sent! as http.MultipartRequest;
      expect(request.fields.keys, ['eventCode']);
    });
  });

  group('counting', () {
    test('counts photos of this person, not the whole album', () async {
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: _FakeClient([
          _match('public', id: 'a'),
          _match('public', id: 'b'),
          _match('myImages', id: 'c'),
          _done,
        ]),
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(search.mineCount.value, 1);
      expect(search.publicCount.value, 2);
    });

    test('takes the event name from the first photo that carries one',
        () async {
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: _FakeClient([
          _match('myImages', id: 'a', eventName: 'Richard Wedding'),
          _done,
        ]),
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(search.eventName.value, 'Richard Wedding');
    });
  });

  group('progress', () {
    test('follows the server through the album', () async {
      // This search has no index to shortcut it, so it genuinely takes a while
      // on a large event — a progress line is the difference between waiting
      // and giving up.
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: _FakeClient([
          '{"type":"progress","processed":10,"total":40,"found":1}',
          '{"type":"progress","processed":20,"total":40,"found":2}',
          _done,
        ]),
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(search.progress.value?.processed, 20);
      expect(search.progress.value?.total, 40);
    });

    test('remembers when the album was larger than one search', () async {
      // "We searched the first 500" and "you are not in this album" are
      // different things, and only one of them is true.
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: _FakeClient(['{"type":"done","truncated":true}']),
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(search.truncated.value, isTrue);
    });

    test('a normal search is not marked truncated', () async {
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: _FakeClient(['{"type":"done","truncated":false}']),
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(search.truncated.value, isFalse);
    });
  });

  group('failure', () {
    test('a refused request is an error', () async {
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: _FakeClient([], status: 400),
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(search.error.value, isNotNull);
      expect(search.isRunning.value, isFalse);
    });

    test('a stream that breaks after finding photos is a result, not a failure',
        () async {
      // The server wrote an identification row per match as it went, so the
      // photos it already found are genuinely found.
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: _FakeClient([_match('myImages', id: 'a')]),
      );
      addTearDown(search.dispose);

      await _run(search);

      expect(search.mineCount.value, 1);
      expect(search.error.value, isNull);
    });
  });

  group('as a LiveSearch', () {
    test('it is one, so the result screen can drive either', () {
      final search = EasySearch(
        code: 'CODE-1',
        faces: _faces(1),
        httpClient: _FakeClient([_done]),
      );
      addTearDown(search.dispose);

      expect(search, isA<LiveSearch>());
      expect(EventScan(code: 'CODE-1'), isA<LiveSearch>());
    });
  });
}
