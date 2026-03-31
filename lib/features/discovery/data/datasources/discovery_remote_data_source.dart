import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

abstract class DiscoveryRemoteDataSource {
  Future<List<EventDiscovery>> getRandomEvents({
    required int take,
    String? userId,
  });
}

class DiscoveryRemoteDataSourceImpl implements DiscoveryRemoteDataSource {
  final Api _api;
  DiscoveryRemoteDataSourceImpl(this._api);

  @override
  Future<List<EventDiscovery>> getRandomEvents({
    required int take,
    String? userId,
  }) async {
    try {
      final params = <String, dynamic>{'take': take};
      if (userId != null && userId.isNotEmpty) params['userId'] = userId;

      final res = await _api.dio.get(
        '/client/random-images',
        queryParameters: params,
      );
      final body = res.data as List<dynamic>;
      return body
          .map((item) =>
              EventDiscovery.fromMap(item as Map<String, dynamic>))
          .toList();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to load events: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }
}
