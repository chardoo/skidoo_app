import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:skidoo_app/features/cart/domain/repositories/cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  final CartRemoteDataSource _remoteDataSource;
  CartRepositoryImpl(this._remoteDataSource);

  @override
  Future<Map<String, dynamic>> initiatePayment(
      String email, String amount) async {
    try {
      return await _remoteDataSource.initiatePayment(email, amount);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Payment initiation error: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> completePayment(
      Map<String, dynamic> payload) async {
    try {
      return await _remoteDataSource.completePayment(payload);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Payment completion error: $e');
    }
  }

  @override
  Future<void> downloadImage(String url) async {
    try {
      await _remoteDataSource.downloadImage(url);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Download error: $e');
    }
  }

  @override
  Future<void> saveImagesFree(List<Map<String, String>> items) async {
    try {
      await _remoteDataSource.saveImagesFree(items);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Free save error: $e');
    }
  }
}
