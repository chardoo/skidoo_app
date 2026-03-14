import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/API/DioClietService.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;
import 'package:skidoo_app/models/event/Event.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

abstract class HomeRemoteDataSource {
  Future<List<Event>> searchEvents(String query);
  Future<List<Photo>> searchEventImages(String eventId, String uniqueName);
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final Api _api;
  HomeRemoteDataSourceImpl(this._api);

  @override
  Future<List<Event>> searchEvents(String query) async {
    try {
      final res = await _api.dio.post(
        '/client/events',
        data: jsonEncode({'queryString': query}),
      );
      final body = res.data as List<dynamic>;
      return body.map((item) => Event.fromMap(item as Map<String, dynamic>)).toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException('Event search failed: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<List<Photo>> searchEventImages(
      String eventId, String uniqueName) async {
    try {
      final res = await _api.dio.post(
        '/client/searchEventImages',
        data: jsonEncode({
          'uiqueName': uniqueName,
          'eventId': eventId,
          'isTrue': true,
        }),
      );
      final body = res.data as List<dynamic>;
      return body.map((item) => Photo.fromMap2(item as Map<String, dynamic>)).toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException('Image search failed: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }
}
