import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;

abstract class CartRemoteDataSource {
  Future<Map<String, dynamic>> initiatePayment(String email, String amount);
  Future<Map<String, dynamic>> completePayment(Map<String, dynamic> payload);
  Future<void> downloadImage(String url);
  Future<void> saveImagesFree(List<Map<String, String>> items);

  /// POST /client/payments/initialize-images
  Future<Map<String, dynamic>> initializeImages({
    required String email,
    required String clientId,
    required List<String> pictureIds,
  });

  /// POST /client/payments/complete-images
  Future<Map<String, dynamic>> completeImages({
    required String referenceId,
    required String clientId,
    required List<Map<String, String>> pictures,
  });

  /// POST /client/payments/ios/intent
  ///
  /// Agrees what this basket costs on iOS and which App Store product pays for
  /// it. Nothing is bought or granted here — it records the basket so the
  /// transaction that comes back later can be matched to it.
  Future<Map<String, dynamic>> iosIntent({
    required String clientId,
    required List<String> pictureIds,
  });

  /// GET /client/payments/ios/quote
  ///
  /// What this basket would cost on iOS, without committing to anything. Used
  /// to label the Pay button honestly: the iOS total is not the sum of the
  /// photo prices.
  Future<Map<String, dynamic>> iosQuote({
    required List<String> pictureIds,
  });

  /// POST /client/payments/ios/verify
  ///
  /// Hands Apple's signed transaction to the server, which verifies the
  /// signature and grants the photos. The app never decides this itself — see
  /// `core/purchase/ios_store.dart`.
  Future<Map<String, dynamic>> iosVerify({
    required String clientId,
    required String orderToken,
    required String signedTransaction,
  });
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
  Future<void> saveImagesFree(List<Map<String, String>> items) async {
    try {
      await _api.dio.post(
        '/client/payments/free',
        data: jsonEncode({'PaidImage': items}),
      );
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Free save failed: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> initializeImages({
    required String email,
    required String clientId,
    required List<String> pictureIds,
  }) async {
    try {
      final res = await _api.dio.post(
        '/client/payments/initialize-images',
        data: jsonEncode(
            {'email': email, 'clientId': clientId, 'pictureIds': pictureIds}),
      );
      if (res.data == null) {
        throw const app_ex.ServerException('Initialize-images returned null.');
      }
      return res.data as Map<String, dynamic>;
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Initialize-images failed: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> completeImages({
    required String referenceId,
    required String clientId,
    required List<Map<String, String>> pictures,
  }) async {
    try {
      final res = await _api.dio.post(
        '/client/payments/complete-images',
        data: jsonEncode({
          'referenceId': referenceId,
          'clientId': clientId,
          'pictures': pictures,
        }),
      );
      if (res.statusCode == 200 && res.data != null) {
        return res.data as Map<String, dynamic>;
      }
      throw app_ex.ServerException('Complete-images failed: ${res.statusCode}');
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Complete-images error: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<void> downloadImage(String url) async {
    // On web, open the image URL directly in a new browser tab — the browser
    // handles the download. saver_gallery and permission_handler are not
    // supported on web.

    try {
      await [Permission.storage, Permission.photos].request();
      final response = await dio.Dio().get(
        url,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      if (response.statusCode != 200) {
        throw app_ex.ServerException('Download failed: ${response.statusCode}');
      }
      final bytes = Uint8List.fromList(response.data as List<int>);
      await SaverGallery.saveImage(
        bytes,
        quality: 100,
        fileName: 'jperg_${DateTime.now().millisecondsSinceEpoch}',
        androidRelativePath: 'Pictures',
        skipIfExists: false,
      );
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Download error: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Download failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> iosIntent({
    required String clientId,
    required List<String> pictureIds,
  }) async {
    try {
      final res = await _api.dio.post(
        '/client/payments/ios/intent',
        data: jsonEncode({'clientId': clientId, 'pictureIds': pictureIds}),
      );
      if (res.data == null) {
        throw const app_ex.ServerException('iOS intent returned null.');
      }
      return res.data as Map<String, dynamic>;
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      // The server's own words where it has any: "this basket is more than a
      // single App Store purchase can cover" tells somebody what to do about
      // it, which a status code does not.
      final data = err.response?.data;
      final error = data is Map ? data['error'] : null;
      final message = error is Map ? error['message'] as String? : null;
      throw app_ex.ServerException(
          message ?? 'Could not start this purchase (${err.response?.statusCode})');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> iosVerify({
    required String clientId,
    required String orderToken,
    required String signedTransaction,
  }) async {
    try {
      final res = await _api.dio.post(
        '/client/payments/ios/verify',
        data: jsonEncode({
          'clientId': clientId,
          'orderToken': orderToken,
          'signedTransaction': signedTransaction,
        }),
      );
      if (res.data == null) {
        throw const app_ex.ServerException('iOS verify returned null.');
      }
      return res.data as Map<String, dynamic>;
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      final data = err.response?.data;
      final error = data is Map ? data['error'] : null;
      final message = error is Map ? error['message'] as String? : null;
      throw app_ex.ServerException(
          message ?? 'Could not confirm this purchase (${err.response?.statusCode})');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> iosQuote({
    required List<String> pictureIds,
  }) async {
    try {
      final res = await _api.dio.get(
        '/client/payments/ios/quote',
        queryParameters: {'pictureIds': pictureIds.join(',')},
      );
      if (res.data == null) {
        throw const app_ex.ServerException('iOS quote returned null.');
      }
      return res.data as Map<String, dynamic>;
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      final data = err.response?.data;
      final error = data is Map ? data['error'] : null;
      final message = error is Map ? error['message'] as String? : null;
      throw app_ex.ServerException(
          message ?? 'Could not price this basket (${err.response?.statusCode})');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }
}
