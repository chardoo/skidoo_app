import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;

/// The file behind a photo, as the server hands it over.
///
/// Carries raw bytes plus the server's Content-Type, because the extension a
/// saved file needs is not knowable from the id — the same endpoint serves a
/// JPEG, a PNG and an MP4.
class OriginalPhotoFile {
  const OriginalPhotoFile({required this.bytes, required this.contentType});

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

/// Fetches the unbadged original of a photo, for saving to the device.
///
/// This used to POST to `.../overlay`, whose whole purpose is to burn the jperg
/// lockup into the pixels — so every photo saved out of the app carried the
/// brand in its corner. A download is a copy of the photograph: the brand
/// belongs on the surfaces the photo is *shown* on, not inside a file that
/// outlives all of that context.
///
/// The server decides whether this caller may have the clean file — free, or
/// bought, or theirs as the photographer or an album owner — and answers 403
/// otherwise. The download button on screen asks the same question, so a 403
/// here means the two disagreed, not that the viewer did something wrong.
abstract class OriginalPhotoRemoteDataSource {
  Future<OriginalPhotoFile> fetchOriginal(String imageId);
}

class OriginalPhotoRemoteDataSourceImpl
    implements OriginalPhotoRemoteDataSource {
  final Api _api;
  OriginalPhotoRemoteDataSourceImpl(this._api);

  @override
  Future<OriginalPhotoFile> fetchOriginal(String imageId) async {
    final endpoint = '/photographer/images/$imageId/download';
    debugPrint('[DOWNLOAD] GET $endpoint');
    try {
      final res = await _api.dio.get<dynamic>(
        endpoint,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      debugPrint(
          '[DOWNLOAD] Response status=${res.statusCode} contentType=${res.headers.value('content-type')} dataType=${res.data?.runtimeType}');

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
            'Unexpected download response type: ${raw.runtimeType}');
      }

      if (bytes.isEmpty) {
        throw const app_ex.ServerException('Download returned empty bytes');
      }

      final contentType = res.headers.value('content-type') ?? 'image/jpeg';

      return OriginalPhotoFile(bytes: bytes, contentType: contentType);
    } on dio.DioException catch (err) {
      debugPrint(
          '[DOWNLOAD] DioException status=${err.response?.statusCode} message=${err.message}');
      debugPrint('[DOWNLOAD] Response body=${err.response?.data}');
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Download failed (${err.response?.statusCode}): ${err.message}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Download error: $e');
    }
  }
}
