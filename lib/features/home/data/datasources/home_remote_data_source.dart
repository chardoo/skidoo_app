import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;
import 'package:skidoo_app/models/event/Event.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

abstract class HomeRemoteDataSource {
  Future<List<Event>> searchEvents(String query);

  /// Streams [Photo] objects as chunks arrive from the server.
  /// The endpoint sends a JSON array in chunked transfer encoding;
  /// each complete `{…}` object is yielded as soon as it is received.
  Stream<Photo> streamEventImages(String eventId, String email);
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final Api _api;
  HomeRemoteDataSourceImpl(this._api);

  // ── Search events ─────────────────────────────────────────────────────────

  @override
  Future<List<Event>> searchEvents(String query) async {
    try {
      final res = await _api.dio.post(
        '/client/events',
        data: {'queryString': query},
      );
      final list = _extractList(res.data);
      return list
          .map((item) => Event.fromMap(item as Map<String, dynamic>))
          .toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Event search failed: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  // ── Stream event images ───────────────────────────────────────────────────

  @override
  Stream<Photo> streamEventImages(String eventId, String email) async* {
    late dio.Response<dio.ResponseBody> response;
    try {
      response = await _api.dio.post<dio.ResponseBody>(
        '/client/search-images',
        data: {
          'eventId': eventId,
          'uiqueName': email, // API has this typo — missing 'n'
          'isTrue': true,
        },
        options: dio.Options(responseType: dio.ResponseType.stream),
      );
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Image stream failed: ${err.response?.statusCode}');
    }

    yield* _parsePhotoStream(response.data!.stream);
  }

  /// Parses the SSE stream from the server.
  ///
  /// The server sends lines of the form:
  ///   data: {"type":"match","category":"myImages","image":{...}}
  ///   data: {"type":"done","total":2}
  ///
  /// Each line is parsed, and only `match` events with a valid `image` payload
  /// are yielded. `done` events signal the end; the stream closes when the
  /// server disconnects.
  Stream<Photo> _parsePhotoStream(Stream<List<int>> byteStream) async* {
    String buffer = '';

    await for (final bytes in byteStream) {
      buffer += utf8.decode(bytes, allowMalformed: true);

      // Process every complete line in the buffer.
      while (true) {
        final newlineIdx = buffer.indexOf('\n');
        if (newlineIdx == -1) break;

        final line = buffer.substring(0, newlineIdx).trim();
        buffer = buffer.substring(newlineIdx + 1);

        // SSE data lines start with "data: "; skip everything else.
        if (!line.startsWith('data: ')) continue;

        final jsonStr = line.substring(6); // strip 'data: '
        try {
          final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = envelope['type'] as String?;

          if (type == 'match') {
            final image = envelope['image'] as Map<String, dynamic>?;
            if (image != null) yield Photo.fromMap2(image);
          }
          // 'done' → stream ends naturally when the server closes the connection.
        } catch (_) {
          // Skip malformed lines.
        }
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in ['data', 'events', 'results', 'items']) {
        if (data[key] is List) return data[key] as List;
      }
    }
    return [];
  }
}
