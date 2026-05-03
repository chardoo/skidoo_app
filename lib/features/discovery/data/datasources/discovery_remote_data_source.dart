import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_ex;
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

abstract class DiscoveryRemoteDataSource {
  Future<List<EventDiscovery>> getRandomEvents({
    required int take,
    String? userId,
  });

  /// GET /photographer/events/{eventId}/images
  Future<EventDiscovery> getEventById(String eventId);
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
      debugPrint('[Discovery] raw response type: ${res.data.runtimeType}');
      debugPrint('[Discovery] raw response: ${res.data}');
      final body = _extractList(res.data);
      debugPrint('[Discovery] extracted list length: ${body.length}');
      final events = <EventDiscovery>[];
      for (var i = 0; i < body.length; i++) {
        try {
          events.add(EventDiscovery.fromMap(body[i] as Map<String, dynamic>));
        } catch (e, st) {
          debugPrint('[Discovery] fromMap failed at index $i: $e\n$st');
          debugPrint('[Discovery] item[$i] = ${body[i]}');
        }
      }
      
      return events;
    } on dio.DioException catch (err) {
      debugPrint('[Discovery] DioException: ${err.message} | status: ${err.response?.statusCode} | body: ${err.response?.data}');
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to load events: ${err.response?.statusCode}');
    } catch (e, st) {
      debugPrint('[Discovery] Unexpected error: $e\n$st');
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  @override
  Future<EventDiscovery> getEventById(String eventId) async {
    try {
      final res = await _api.dio.get('/photographer/events/$eventId/images');
      final data = res.data as Map<String, dynamic>;
      debugPrint('[Discovery] getEventById raw keys: ${data.keys.toList()}');
      debugPrint('[Discovery] getEventById raw: $data');
      return EventDiscovery.fromMap(data);
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Failed to load event: ${err.response?.statusCode}');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      debugPrint('[Discovery] response keys: ${data.keys.toList()}');
      // Try common wrapper keys first, then fall back to first list value.
      for (final key in ['data', 'events', 'results', 'items', 'randomImages', 'randomEvents']) {
        if (data[key] is List) return data[key] as List;
      }
      // Last resort: return the first value that is a List.
      for (final value in data.values) {
        if (value is List) return value;
      }
    }
    debugPrint('[Discovery] _extractList: could not find a List in response');
    return [];
  }
}
