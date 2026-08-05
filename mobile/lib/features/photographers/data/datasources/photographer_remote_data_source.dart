import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;
import 'package:skidoo_app/models/photographer/photographer_event.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

abstract class PhotographerRemoteDataSource {
  Future<List<PhotographerModel>> getPhotographers();
  Future<List<PhotographerModel>> searchPhotographers(String query);
  Future<List<PhotographerSample>> getSamples(String photographerId);
  Future<List<PhotographerSample>> uploadSamples({
    required String photographerId,
    required List<XFile> files,
  });
  Future<void> deleteSample({
    required String sampleId,
    required String photographerId,
  });
  Future<PhotographerEventsResult> getPhotographerEvents({
    required String photographerId,
    required int page,
    required int limit,
  });
  Future<Map<String, dynamic>> getPhotographerProfile(String photographerId);
  Future<void> updatePhotographerProfile({
    required String photographerId,
    String? studioName,
    String? bio,
    List<String>? specialties,
    String? location,
  });
  Future<String> uploadProfilePhoto({
    required String photographerId,
    required XFile photo,
  });
  Future<String> uploadStudioImage({
    required String photographerId,
    required XFile image,
  });
  Future<void> submitVerification({
    required String photographerId,
    required XFile idDocument,
    required bool acceptedTerms,
    required bool confirmedUploadRights,
    required bool acceptedPayoutPolicy,
  });
}

class PhotographerRemoteDataSourceImpl implements PhotographerRemoteDataSource {
  final Api _api;
  PhotographerRemoteDataSourceImpl(this._api);

  @override
  Future<List<PhotographerModel>> getPhotographers() async {
    try {
      final res = await _api.dio.get('/client/photographers');
      final body = res.data as List<dynamic>;
      return body
          .map((item) =>
              PhotographerModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to load photographers: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<List<PhotographerModel>> searchPhotographers(String query) async {
    try {
      final res = await _api.dio.post(
        '/client/photographers',
        data: jsonEncode({'queryString': query}),
      );
      final body = res.data as List<dynamic>;
      return body
          .map((item) =>
              PhotographerModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Search failed: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<List<PhotographerSample>> getSamples(String photographerId) async {
    try {
      final res = await _api.dio.post(
        '/photographer/samples',
        data: jsonEncode({'userId': photographerId}),
      );
      final body = res.data as List<dynamic>;
      return body
          .map((item) =>
              PhotographerSample.fromJson(item as Map<String, dynamic>))
          .toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to load samples: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<List<PhotographerSample>> uploadSamples({
    required String photographerId,
    required List<XFile> files,
  }) async {
    try {
      final multiparts = await Future.wait(files.map((f) async =>
          dio.MultipartFile.fromBytes(
            await f.readAsBytes(),
            filename: f.name,
          )));
      final formData = dio.FormData.fromMap({
        'userId': photographerId,
        'files': multiparts,
      });
      final res = await _api.dio.put(
        '/photographer/samples',
        data: formData,
        options: dio.Options(
          contentType: 'multipart/form-data',
          // Two clocks, and they cover different halves of this request.
          // sendTimeout is the upload of the multipart body; receiveTimeout is
          // the wait afterwards, while the server pushes each file to
          // Cloudinary and only then answers. It is the second one that this
          // endpoint spends its time in, and it was the one left implicit —
          // inheriting 60 s from the base client while sendTimeout had been
          // raised to two minutes. Stated here so the pair is visible together.
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final body = res.data as List<dynamic>;
      return body
          .map((item) =>
              PhotographerSample.fromJson(item as Map<String, dynamic>))
          .toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to upload samples: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<void> deleteSample({
    required String sampleId,
    required String photographerId,
  }) async {
    try {
      await _api.dio.delete(
        '/photographer/samples',
        data: jsonEncode({'sampleId': sampleId, 'userId': photographerId}),
      );
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to delete sample: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<PhotographerEventsResult> getPhotographerEvents({
    required String photographerId,
    required int page,
    required int limit,
  }) async {
    try {
      final res = await _api.dio.get(
        '/photographer/events',
        queryParameters: {
          'userId': photographerId,
          'page': page,
          'limit': limit,
        },
      );
      final list = _extractList(res.data);
      final events = list
          .map((item) =>
              PhotographerEvent.fromJson(item as Map<String, dynamic>))
          .toList();

      // Extract hasNext from pagination if present.
      bool hasNext = false;
      final raw = res.data;
      if (raw is Map<String, dynamic>) {
        final pagination = raw['pagination'] as Map<String, dynamic>?;
        hasNext = (pagination?['hasNext'] as bool?) ?? false;
      }

      return PhotographerEventsResult(events: events, hasNext: hasNext);
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to load events: ${err.response?.statusCode} — ${err.response?.data}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getPhotographerProfile(
      String photographerId) async {
    try {
      final res = await _api.dio.get('/photographer/profile/$photographerId');
      return res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to load profile: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  /// `PATCH /photographer/profile/{id}` — confirmed contract
  /// (`docs/FRONTEND_PROFILE_AND_SAMPLES.md`): multipart form, `bio`/
  /// `specialties`/`studio_name`/`location`. Photo uploads are separate dedicated
  /// endpoints — see [uploadProfilePhoto] / [uploadStudioImage].
  @override
  Future<void> updatePhotographerProfile({
    required String photographerId,
    String? studioName,
    String? bio,
    List<String>? specialties,
    String? location,
  }) async {
    try {
      final formData = dio.FormData.fromMap({
        if (studioName != null) 'studio_name': studioName,
        if (bio != null) 'bio': bio,
        if (location != null) 'location': location,
        if (specialties != null) 'specialties': jsonEncode(specialties),
      });
      await _api.dio.patch(
        '/photographer/profile/$photographerId',
        data: formData,
        options: dio.Options(contentType: 'multipart/form-data'),
      );
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to update profile: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  /// `POST /photographer/profile/{id}/photo` — confirmed contract. Personal
  /// avatar, distinct from [uploadStudioImage].
  @override
  Future<String> uploadProfilePhoto({
    required String photographerId,
    required XFile photo,
  }) async {
    try {
      final formData = dio.FormData.fromMap({
        'file': dio.MultipartFile.fromBytes(
          await photo.readAsBytes(),
          filename: photo.name,
        ),
      });
      final res = await _api.dio.post(
        '/photographer/profile/$photographerId/photo',
        data: formData,
        options: dio.Options(contentType: 'multipart/form-data'),
      );
      final body = res.data;
      return body is Map ? (body['profile_url']?.toString() ?? '') : '';
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to upload profile photo: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  /// `POST /photographer/profile/{id}/studio-image` — confirmed contract.
  /// Single image, each call replaces the previous one. Response:
  /// `{"id": "...", "studio_image_url": "..."}`.
  @override
  Future<String> uploadStudioImage({
    required String photographerId,
    required XFile image,
  }) async {
    try {
      final formData = dio.FormData.fromMap({
        'file': dio.MultipartFile.fromBytes(
          await image.readAsBytes(),
          filename: image.name,
        ),
      });
      final res = await _api.dio.post(
        '/photographer/profile/$photographerId/studio-image',
        data: formData,
        options: dio.Options(contentType: 'multipart/form-data'),
      );
      final body = res.data;
      return body is Map ? (body['studio_image_url']?.toString() ?? '') : '';
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to upload studio image: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  /// **Assumed** endpoint — no backend contract exists for this yet. See the
  /// doc comment on [PhotographerRepository.submitVerification].
  @override
  Future<void> submitVerification({
    required String photographerId,
    required XFile idDocument,
    required bool acceptedTerms,
    required bool confirmedUploadRights,
    required bool acceptedPayoutPolicy,
  }) async {
    try {
      final formData = dio.FormData.fromMap({
        'userId': photographerId,
        'accepted_terms': acceptedTerms.toString(),
        'confirmed_upload_rights': confirmedUploadRights.toString(),
        'accepted_payout_policy': acceptedPayoutPolicy.toString(),
        'file': dio.MultipartFile.fromBytes(
          await idDocument.readAsBytes(),
          filename: idDocument.name,
        ),
      });
      await _api.dio.post(
        '/photographer/verification',
        data: formData,
        options: dio.Options(contentType: 'multipart/form-data'),
      );
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to submit verification: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

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
