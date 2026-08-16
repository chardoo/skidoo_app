import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_media_limits.dart';
import 'package:jperg_app/features/chat/data/network/chat_api_client.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Every upload failure used to reach the user as "Failed to upload image",
/// whatever had actually gone wrong — over the size cap, an unsupported type,
/// storage not configured on the server. That is unactionable for the user and
/// undiagnosable from a bug report.
void main() {
  group('uploadErrorText', () {
    test('prefers what the server said', () {
      expect(
        uploadErrorText(
          const ApiException('Chat API error 400: {...}',
              statusCode: 400,
              serverMessage: 'File exceeds the 10 MB limit for videos'),
          isVideo: true,
        ),
        'File exceeds the 10 MB limit for videos',
      );
    });

    test('never shows the debug string, which carries the raw body', () {
      final text = uploadErrorText(
        const ApiException('Chat API error 500: {trace: ...}', statusCode: 500),
        isVideo: false,
      );
      expect(text, isNot(contains('Chat API error')));
      expect(text, 'Could not upload the image. Please try again.');
    });

    test('names the medium so the message fits what was attempted', () {
      expect(uploadErrorText(const NetworkException(), isVideo: true),
          contains('video'));
      expect(uploadErrorText(const NetworkException(), isVideo: false),
          contains('image'));
    });

    test('a signed-out upload says so rather than blaming the file', () {
      expect(
        uploadErrorText(const ApiException('x', statusCode: 403), isVideo: true),
        'You are not signed in to send a video.',
      );
      expect(
        uploadErrorText(const ApiException('x', statusCode: 401), isVideo: false),
        'You are not signed in to send an image.',
      );
    });
  });

  group('ChatMediaLimitsService', () {
    ChatApiClient clientReturning(dynamic body, {int status = 200}) {
      final c = ChatApiClient(AuthService());
      c.dio.httpClientAdapter = _StubAdapter(body, status);
      return c;
    }

    test('reads the caps the server actually enforces', () async {
      final limits = await ChatMediaLimitsService(
        clientReturning({'max_image_size_mb': 8, 'max_video_size_mb': 25}),
      ).get();

      expect(limits.maxImageBytes, 8 * 1024 * 1024);
      expect(limits.maxVideoBytes, 25 * 1024 * 1024);
    });

    test('falls back to the shipped defaults when the server cannot be asked',
        () async {
      // Blocking uploads outright because a config read failed would be worse
      // than assuming the documented defaults.
      final limits = await ChatMediaLimitsService(
        clientReturning({'detail': 'nope'}, status: 500),
      ).get();

      expect(limits.maxImageBytes, ChatMediaLimits.fallback.maxImageBytes);
      expect(limits.maxVideoBytes, ChatMediaLimits.fallback.maxVideoBytes);
    });

    test('a nonsense payload does not produce a zero-byte cap', () async {
      // A cap of 0 would reject every file with "maximum size is 0 MB".
      final limits = await ChatMediaLimitsService(
        clientReturning({'max_image_size_mb': 0, 'max_video_size_mb': null}),
      ).get();

      expect(limits.maxImageBytes, ChatMediaLimits.fallback.maxImageBytes);
      expect(limits.maxVideoBytes, ChatMediaLimits.fallback.maxVideoBytes);
    });

    test('asks once and reuses the answer', () async {
      final client = clientReturning(
          {'max_image_size_mb': 8, 'max_video_size_mb': 8});
      final adapter = client.dio.httpClientAdapter as _StubAdapter;
      final service = ChatMediaLimitsService(client);

      // Concurrently, as two pickers opened in quick succession would.
      await Future.wait([service.get(), service.get()]);
      await service.get();

      expect(adapter.calls, 1);
    });

    test('the defaults match what the chat service ships with', () {
      // Keep in step with _DEFAULTS in chat/app/services/media_config.py — a
      // client cap above the server's is the bad case: the file uploads in full
      // and is only then refused.
      expect(ChatMediaLimits.fallback.maxImageBytes, 10 * 1024 * 1024);
      expect(ChatMediaLimits.fallback.maxVideoBytes, 10 * 1024 * 1024);
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, this.status);
  final dynamic body;
  final int status;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(
      body is String ? body as String : _encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  static String _encode(dynamic v) {
    if (v is Map) {
      final parts = v.entries.map((e) =>
          '"${e.key}":${e.value == null ? 'null' : (e.value is num ? e.value : '"${e.value}"')}');
      return '{${parts.join(',')}}';
    }
    return '$v';
  }

  @override
  void close({bool force = false}) {}
}
