import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/gallery/data/event_scan.dart';
import 'package:jperg_app/services/auth_service.dart';

/// One run of `POST /client/easy-search` — finding someone without keeping
/// their face.
///
/// The same answer [EventScan] gets, for people who will not enrol. The selfies
/// travel with the request, the face service compares them and keeps nothing,
/// and a second search means sending them again. That is the trade: no stored
/// biometrics, and no cheap lookup afterwards either.
///
/// Everything downstream is deliberately identical to [EventScan] — the same
/// `match` / `progress` / `done` envelope, the same two counters, the same
/// album to walk into — which is why both are a [LiveSearch] and the result
/// screen cannot tell them apart.
///
/// **Multipart, so `http.MultipartRequest`.** `send()` still gives a streamed
/// response, which is what SSE needs; what it costs is that the selfie bytes
/// must be in memory when the request is built, since the files behind them may
/// be gone by the time the stream is read.
class EasySearch implements LiveSearch {
  EasySearch({
    required this.code,
    required this.faces,
    http.Client? httpClient,
  })  : assert(faces.isNotEmpty && faces.length <= maxFaces),
        _http = httpClient ?? http.Client();

  /// The server's own limit, and the face service's behind it: at most four
  /// reference photos per request.
  static const int maxFaces = 4;

  /// An event id or an access code — the server resolves either.
  final String code;

  /// The selfies, already read into memory. See the class doc.
  final List<({String name, Uint8List bytes})> faces;

  final http.Client _http;

  @override
  final ValueNotifier<int> mineCount = ValueNotifier<int>(0);

  @override
  final ValueNotifier<int> publicCount = ValueNotifier<int>(0);

  @override
  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(true);

  @override
  final ValueNotifier<Object?> error = ValueNotifier<Object?>(null);

  @override
  final ValueNotifier<String?> eventName = ValueNotifier<String?>(null);

  /// How far through the album the server is, for a search that has no index to
  /// shortcut it — this one genuinely takes a while on a large event, and a
  /// progress line is the difference between waiting and giving up.
  @override
  final ValueNotifier<({int processed, int total})?> progress =
      ValueNotifier<({int processed, int total})?>(null);

  /// True when the album was larger than one search covers. The screen says so
  /// rather than letting "we searched the first 500" read as "you are not in
  /// this album".
  @override
  final ValueNotifier<bool> truncated = ValueNotifier<bool>(false);

  StreamSubscription<List<int>>? _sub;
  bool _disposed = false;
  String _buffer = '';
  int _unsignalled = 0;

  static const _signalEvery = 5;

  /// Reads the captured files into memory, ready to be sent.
  ///
  /// Here rather than in the page because the bytes are the thing this class
  /// needs, and the page should not have to know that a `XFile` on disk is not
  /// good enough. Anything unreadable is skipped — a selfie that cannot be
  /// loaded is not worth failing a search over when three others loaded fine.
  static Future<List<({String name, Uint8List bytes})>> readFaces(
    List<XFile> files,
  ) async {
    final out = <({String name, Uint8List bytes})>[];
    for (var i = 0; i < files.length && out.length < maxFaces; i++) {
      try {
        final bytes = await files[i].readAsBytes();
        if (bytes.isEmpty) continue;
        out.add((name: 'selfie_$i.jpg', bytes: bytes));
      } catch (_) {
        // Skipped on purpose — see above.
      }
    }
    return out;
  }

  @override
  Future<void> start() async {
    try {
      final api = sl<Api>();
      final uri = Uri.parse('${api.dio.options.baseUrl}/client/easy-search');

      // Raw http rather than Dio, as in [EventScan]: SSE needs the streamed
      // body, so Dio's interceptors do not run and the token goes on by hand.
      String token = '';
      try {
        token = await sl<AuthService>().getToken();
      } catch (_) {}

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Accept': 'text/event-stream',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        })
        // Whose photos still comes from the token. The code says *which album*;
        // it does not say who to look for.
        ..fields['eventCode'] = code;

      for (final face in faces) {
        request.files.add(
          http.MultipartFile.fromBytes('faces', face.bytes, filename: face.name),
        );
      }

      final response = await _http.send(request);
      if (response.statusCode != 200) {
        // The server's words, and a typed [EventNotFound] for a code that
        // names nothing — see `failureFrom`. Typing a wrong code is the
        // likeliest way this fails, and it used to read as "no photos of you".
        _finish(error: await failureFrom(response));
        return;
      }

      _sub = response.stream.listen(
        _onBytes,
        onDone: () => _finish(),
        onError: (Object e) => _finish(error: e),
        cancelOnError: true,
      );
    } catch (e) {
      _finish(error: e);
    }
  }

  void _onBytes(List<int> bytes) {
    _buffer += utf8.decode(bytes, allowMalformed: true);
    while (true) {
      final nl = _buffer.indexOf('\n');
      if (nl == -1) break;
      final line = _buffer.substring(0, nl).trim();
      _buffer = _buffer.substring(nl + 1);
      if (!line.startsWith('data: ')) continue;

      Map<String, dynamic> envelope;
      try {
        envelope = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      _onEnvelope(envelope);
    }
  }

  void _onEnvelope(Map<String, dynamic> envelope) {
    switch (envelope['type']) {
      case 'match':
        _countMatch(
          envelope['category'] as String?,
          envelope['image'] as Map<String, dynamic>?,
        );
      case 'progress':
        final processed = envelope['processed'];
        final total = envelope['total'];
        if (processed is int && total is int) {
          progress.value = (processed: processed, total: total);
        }
      case 'done':
        if (envelope['truncated'] == true) truncated.value = true;
        _finish();
    }
  }

  void _countMatch(String? category, Map<String, dynamic>? image) {
    if (image == null) return;
    eventName.value ??= _eventNameOf(image);

    if (category != 'myImages') {
      if (category == 'public') publicCount.value++;
      return;
    }

    mineCount.value++;
    _unsignalled++;
    if (_unsignalled >= _signalEvery) _signal();
  }

  String? _eventNameOf(Map<String, dynamic> image) {
    final event = image['event'];
    if (event is Map && event['eventName'] is String) {
      return event['eventName'] as String;
    }
    return image['eventName'] as String?;
  }

  void _signal() {
    _unsignalled = 0;
    try {
      AppCacheSignals.foundPhotos.bump();
    } catch (_) {
      // A signal is a refresh hint; failing to send one is not worth an error
      // over someone's photos.
    }
  }

  void _finish({Object? error}) {
    if (_disposed || !isRunning.value) return;
    // Only an error when it produced nothing. The server writes an
    // identification row per match as it goes, so a stream that broke late
    // still found what it found.
    if (error != null && mineCount.value == 0) this.error.value = error;
    isRunning.value = false;
    if (_unsignalled > 0) _signal();
  }

  @override
  void cancel() {
    _sub?.cancel();
    _sub = null;
    if (isRunning.value) isRunning.value = false;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
    _http.close();
    mineCount.dispose();
    publicCount.dispose();
    isRunning.dispose();
    error.dispose();
    eventName.dispose();
    progress.dispose();
    truncated.dispose();
  }
}
