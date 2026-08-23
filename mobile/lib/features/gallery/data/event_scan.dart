import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/services/auth_service.dart';

/// One run of `POST /client/search-images` for a scanned or typed event code.
///
/// Why this is not just a Stream the scan page listens to: the page offers
/// "View photos" while the scan is still going, and navigating away from a
/// page cancels anything its State was holding. The scan has to outlive the
/// screen that started it — the photos keep arriving, and the album the user
/// walked into keeps filling.
///
/// **Why the live scan and not `/client/my-photos`.** That endpoint reads
/// stored `ImageIdentification` rows. An event uploaded before the person had
/// an account has none — the upload worker matched those photos against an
/// index their face was not in yet — so it answers "nothing found", correctly
/// and forever. This runs recognition *now*, and writes the rows as it goes.
/// That is also what makes the review album work afterwards: it reads the rows
/// this created.
class EventScan {
  EventScan({required this.code, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// An event id or an access code — the server resolves either.
  final String code;

  final http.Client _http;

  /// Photos of *this person*, which is what the screen counts. Deliberately
  /// not every photo streamed: an owner scanning their own event receives the
  /// whole album in the `public` bucket, and "247 photos of you found" would
  /// be a lie about someone else's wedding.
  final ValueNotifier<int> mineCount = ValueNotifier<int>(0);

  /// False once the stream closes, however it closed.
  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(true);

  /// Set only when nothing could be scanned at all. A stream that delivered
  /// photos and then broke is a result, not a failure — the photos it found
  /// are genuinely found, and the rows are already written.
  final ValueNotifier<Object?> error = ValueNotifier<Object?>(null);

  /// The event's name, from the first photo to carry it. The result card names
  /// the album, and nothing else on this screen knows it.
  final ValueNotifier<String?> eventName = ValueNotifier<String?>(null);

  StreamSubscription<List<int>>? _sub;
  bool _disposed = false;
  String _buffer = '';

  /// New matches since the last signal, so the album is not told to refetch
  /// once per photo.
  int _unsignalled = 0;

  Future<void> start() async {
    try {
      final api = sl<Api>();
      final uri = Uri.parse('${api.dio.options.baseUrl}/client/search-images');

      // Raw http rather than Dio: SSE needs the streamed response body, which
      // means Dio's interceptors do not run and the bearer token has to be
      // attached by hand.
      String token = '';
      try {
        token = await sl<AuthService>().getToken();
      } catch (_) {}

      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Accept': 'text/event-stream',
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        })
        // No uiqueName. Whose face to look for comes from the token — the
        // server ignores a body value, and has to: a person id the request
        // could name is a person id it could name for somebody else.
        ..body = jsonEncode({'eventId': code});

      final response = await _http.send(request);
      if (response.statusCode != 200) {
        _finish(error: 'Scan failed: ${response.statusCode}');
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
      case 'match_batch':
        final images = envelope['images'];
        if (images is List) {
          for (final image in images) {
            _countMatch(
              envelope['category'] as String?,
              image is Map<String, dynamic> ? image : null,
            );
          }
        }
      case 'done':
        _finish();
    }
  }

  void _countMatch(String? category, Map<String, dynamic>? image) {
    if (image == null) return;
    eventName.value ??= _eventNameOf(image);

    // 'public' is the event's own photos, which an owner gets in full. Only
    // 'myImages' is this person.
    if (category != 'myImages') return;

    mineCount.value++;
    _unsignalled++;
    // Batched: the album refetches on this signal, and one refetch per photo
    // would put a request behind every tile.
    if (_unsignalled >= _signalEvery) _signal();
  }

  static const _signalEvery = 5;

  String? _eventNameOf(Map<String, dynamic> image) {
    final event = image['event'];
    if (event is Map && event['eventName'] is String) {
      return event['eventName'] as String;
    }
    return image['eventName'] as String?;
  }

  /// Tells anything showing these photos that there are more.
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
    // Only an error when it produced nothing. Photos already delivered are
    // already written server-side, so a stream that broke late is a result.
    if (error != null && mineCount.value == 0) this.error.value = error;
    isRunning.value = false;
    // Whatever is left, so the album sees the tail of the scan.
    if (_unsignalled > 0) _signal();
  }

  /// Stops the scan. Called when the person leaves without opening the album —
  /// a discarded scan should not keep spending recognition calls.
  void cancel() {
    _sub?.cancel();
    _sub = null;
    if (isRunning.value) isRunning.value = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
    _http.close();
    mineCount.dispose();
    isRunning.dispose();
    error.dispose();
    eventName.dispose();
  }
}
