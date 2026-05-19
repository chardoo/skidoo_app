import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;
import 'package:skidoo_app/models/photos/Photo.dart';

abstract class GalleryRemoteDataSource {
  Future<List<Photo>> getUserGallery(String clientId);
}

class GalleryRemoteDataSourceImpl implements GalleryRemoteDataSource {
  final Api _api;
  GalleryRemoteDataSourceImpl(this._api);

  @override
  Future<List<Photo>> getUserGallery(String clientId) async {
    try {
      final res = await _api.dio.post(
        '/client/dashboard',
        data: jsonEncode({'clientId': clientId, 'page': 1, 'limit': 25}),
      );
      final raw = res.data;
      final List<dynamic> body;
      if (raw is Map<String, dynamic> && raw['data'] is List) {
        body = raw['data'] as List<dynamic>;
      } else if (raw is List) {
        body = raw;
      } else {
        body = [];
      }
      return body
          .map((item) => Photo.fromMap(item as Map<String, dynamic>))
          .toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Gallery load failed: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }
}
