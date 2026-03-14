import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/API/DioClietService.dart';
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
        '/client/clientDashboard',
        data: jsonEncode({'clientId': clientId}),
      );
      final body = res.data as List<dynamic>;
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
