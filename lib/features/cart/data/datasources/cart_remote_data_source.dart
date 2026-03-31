import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;

abstract class CartRemoteDataSource {
  Future<Map<String, dynamic>> initiatePayment(String email, String amount);
  Future<Map<String, dynamic>> completePayment(Map<String, dynamic> payload);
  Future<void> downloadImage(String url);
}

class CartRemoteDataSourceImpl implements CartRemoteDataSource {
  final Api _api;
  CartRemoteDataSourceImpl(this._api);

  @override
  Future<Map<String, dynamic>> initiatePayment(
      String email, String amount) async {
    try {
      final res = await _api.dio.post(
        '/client/payments/initialize',
        data: jsonEncode({'email': email, 'amount': amount}),
      );
      if (res.data == null || res.data == false) {
        throw const app_ex.ServerException('Payment initiation returned null.');
      }
      return res.data as Map<String, dynamic>;
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Payment initiation failed: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> completePayment(
      Map<String, dynamic> payload) async {
    try {
      final res = await _api.dio.post(
        '/client/payments/complete',
        data: jsonEncode(payload),
      );
      if (res.statusCode == 200 && res.data != null) {
        return res.data as Map<String, dynamic>;
      }
      throw app_ex.ServerException(
          'Payment completion failed: ${res.statusCode}');
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Payment completion error: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<void> downloadImage(String url) async {
    try {
      await [Permission.storage, Permission.photos].request();
      final response = await dio.Dio().get(
        url,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      if (response.statusCode != 200) {
        throw app_ex.ServerException(
            'Download failed: ${response.statusCode}');
      }
      final bytes = Uint8List.fromList(response.data as List<int>);
      await ImageGallerySaver.saveImage(bytes);
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Download error: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Download failed: $e');
    }
  }
}
