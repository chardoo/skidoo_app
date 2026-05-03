import 'dart:convert';

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
  Future<PhotographerEventsResult> getPhotographerEvents({
    required String photographerId,
    required int page,
    required int limit,
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
        '/api/photographer/samples',
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
