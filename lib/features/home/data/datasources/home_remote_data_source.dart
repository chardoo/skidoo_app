import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;
import 'package:skidoo_app/models/event/Event.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:http/http.dart' as http;
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
  final uri = Uri.parse('${_api.dio.options.baseUrl}/client/search-images');

  final request = http.Request('POST', uri)
    ..headers.addAll({
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json',
    })
    ..body = jsonEncode({
      'eventId': eventId,
      'uiqueName': email,
      'isTrue': true,
    });

  final response = await request.send();

  if (response.statusCode != 200) {
    throw Exception('Stream failed: ${response.statusCode}');
  }

  yield* _parsePhotoStream(response.stream, DateTime.now());
}


  /// Parses the SSE byte stream.
  /// Logs every chunk with a wall-clock timestamp so you can see whether
  /// data truly trickles in or arrives in one burst.
  Stream<Photo> _parsePhotoStream(
      Stream<List<int>> byteStream, DateTime t0) async* {
    String buffer = '';
    int chunkIndex = 0;
    int photoIndex = 0;
    DateTime? tFirstChunk;
    DateTime? tFirstPhoto;

    await for (final bytes in byteStream) {
      final tChunk = DateTime.now();
      tFirstChunk ??= tChunk;
      chunkIndex++;

      final text = utf8.decode(bytes, allowMalformed: true);
      _dbg('CHUNK #$chunkIndex  ${bytes.length}B  '
          '+${tChunk.difference(tFirstChunk).inMilliseconds}ms since first chunk\n'
          '  raw: ${text.length > 200 ? '${text.substring(0, 200)}…' : text}',
          t0, tChunk);

      buffer += text;

      // Extract every complete newline-terminated line from the buffer.
      while (true) {
        final nl = buffer.indexOf('\n');
        if (nl == -1) break;
        final line = buffer.substring(0, nl).trim();
        buffer = buffer.substring(nl + 1);

        if (line.isEmpty) continue; // blank SSE separator

        if (!line.startsWith('data: ')) {
          // Log non-data lines (event:, id:, comments, etc.)
          _dbg('  NON-DATA line: $line', t0, DateTime.now());
          continue;
        }

        final jsonStr = line.substring(6); // strip 'data: '
        Map<String, dynamic> envelope;
        try {
          envelope = jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (e) {
          _dbg('  JSON PARSE ERROR: $e\n  raw: $jsonStr', t0, DateTime.now());
          continue;
        }

        final type = envelope['type'] as String?;
        _dbg('  SSE type="$type"', t0, DateTime.now());

        if (type == 'match') {
          final image = envelope['image'] as Map<String, dynamic>?;
          if (image != null) {
            final tPhoto = DateTime.now();
            tFirstPhoto ??= tPhoto;
            photoIndex++;
            _dbg('  >>> PHOTO #$photoIndex  id=${image['id']}  '
                '+${tPhoto.difference(t0).inMilliseconds}ms since request',
                t0, tPhoto);
            yield Photo.fromMap2(image);
          }
        } else if (type == 'match_batch') {
          final images = envelope['images'] as List<dynamic>?;
          if (images != null) {
            for (final raw in images) {
              final image = raw as Map<String, dynamic>;
              final tPhoto = DateTime.now();
              tFirstPhoto ??= tPhoto;
              photoIndex++;
              _dbg('  >>> PHOTO #$photoIndex (batch)  id=${image['id']}  '
                  '+${tPhoto.difference(t0).inMilliseconds}ms since request',
                  t0, tPhoto);
              yield Photo.fromMap2(image);
            }
          }
        } else if (type == 'progress') {
          _dbg('  progress ${envelope['processed']}/${envelope['total']}',
              t0, DateTime.now());
        } else if (type == 'done') {
          final chunkLag = tFirstChunk!.difference(t0).inMilliseconds;
          final photoLag = tFirstPhoto?.difference(t0).inMilliseconds ?? -1;
          _dbg('DONE  total=${envelope['total']}  '
              'photos_yielded=$photoIndex  '
              'first_chunk_lag=${chunkLag}ms  '
              'first_photo_lag=${photoLag}ms',
              t0, DateTime.now());
        } else if (type == 'heartbeat') {
          _dbg('  heartbeat', t0, DateTime.now());
        }
      }
    }

    // Buffer might still hold a partial/complete line if server didn't end with \n
    if (buffer.trim().isNotEmpty) {
      _dbg('LEFTOVER BUFFER (no trailing newline):\n  $buffer', t0, DateTime.now());
    }

    _dbg('STREAM ENDED  total_chunks=$chunkIndex  total_photos=$photoIndex',
        t0, DateTime.now());
  }

  /// Structured timestamped logger.
  /// Format: [SSE +<ms>ms] <message>
  static void _dbg(String msg, DateTime t0, DateTime now) {
    final elapsed = now.difference(t0).inMilliseconds;
    debugPrint('[SSE +${elapsed}ms] $msg');
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
