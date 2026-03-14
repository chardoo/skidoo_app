import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/API/DioClietService.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;
import 'package:skidoo_app/models/photographer/photographerModel.dart';

abstract class PhotographerRemoteDataSource {
  Future<List<PhotographerModel>> getPhotographers();
  Future<List<PhotographerModel>> searchPhotographers(String query);
}

class PhotographerRemoteDataSourceImpl implements PhotographerRemoteDataSource {
  final Api _api;
  PhotographerRemoteDataSourceImpl(this._api);

  @override
  Future<List<PhotographerModel>> getPhotographers() async {
    try {
      final res = await _api.dio.post('/client/getphotographers',
          data: jsonEncode({'queryString': ''}));
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
        '/client/searchPhotographers',
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
}
