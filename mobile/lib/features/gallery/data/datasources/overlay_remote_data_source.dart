import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;

/// Payload returned by the overlay endpoint.
/// Carries raw bytes + the server's Content-Type so callers pick the right
/// file extension (.jpg, .mp4, etc.).
class OverlayResult {
  const OverlayResult({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType; // e.g. 'image/jpeg', 'video/mp4'

  String get fileExtension {
    if (contentType.contains('mp4')) return 'mp4';
    if (contentType.contains('webm')) return 'webm';
    if (contentType.contains('mov')) return 'mov';
    if (contentType.contains('png')) return 'png';
    if (contentType.contains('gif')) return 'gif';
    return 'jpg';
  }

  bool get isVideo => contentType.startsWith('video/');
}

abstract class OverlayRemoteDataSource {
  Future<OverlayResult> getOverlayImage(
      String imageId, String photographerName);
}

class OverlayRemoteDataSourceImpl implements OverlayRemoteDataSource {
  final Api _api;
  OverlayRemoteDataSourceImpl(this._api);

  @override
  Future<OverlayResult> getOverlayImage(
      String imageId, String photographerName) async {
    final endpoint = '/photographer/images/$imageId/overlay';
    debugPrint('[OVERLAY] POST $endpoint  photographerName="$photographerName"');
    try {
      // Use jsonEncode explicitly — when responseType is bytes Dio may not
      // auto-encode the Map, leading to a malformed request body.
      final res = await _api.dio.post<dynamic>(
        endpoint,
        data: jsonEncode({'enabled': true, 'photographerName': photographerName}),
        options: dio.Options(
          responseType: dio.ResponseType.bytes,
          // Keep content-type as JSON for the request body.
          contentType: 'application/json',
        ),
      );
      debugPrint('[OVERLAY] Response status=${res.statusCode} contentType=${res.headers.value('content-type')} dataType=${res.data?.runtimeType}');

      // Dio returns Uint8List for ResponseType.bytes — handle both cases
      // defensively so a runtime type mismatch never produces an empty buffer.
      final raw = res.data;
      final Uint8List bytes;
      if (raw is Uint8List) {
        bytes = raw;
      } else if (raw is List) {
        bytes = Uint8List.fromList(raw.cast<int>());
      } else {
        throw app_ex.ServerException(
            'Unexpected overlay response type: ${raw.runtimeType}');
      }

      if (bytes.isEmpty) {
        throw const app_ex.ServerException('Overlay returned empty bytes');
      }

      final contentType =
          res.headers.value('content-type') ?? 'image/jpeg';

      return OverlayResult(bytes: bytes, contentType: contentType);
    } on dio.DioException catch (err) {
      debugPrint('[OVERLAY] DioException status=${err.response?.statusCode} message=${err.message}');
      debugPrint('[OVERLAY] Response body=${err.response?.data}');
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Overlay failed (${err.response?.statusCode}): ${err.message}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Overlay error: $e');
    }
  }
}
