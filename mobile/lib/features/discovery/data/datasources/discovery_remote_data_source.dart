import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

abstract class DiscoveryRemoteDataSource {
  Future<List<EventDiscovery>> getRandomEvents({
    required int take,
    required int skip,
    String? userId,
    List<String>? followedPhotographerIds,
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
    required int skip,
    String? userId,
    List<String>? followedPhotographerIds,
  }) async {
    try {
      final params = <String, dynamic>{'take': take, 'skip': skip};
      if (userId != null && userId.isNotEmpty) params['userId'] = userId;
      if (followedPhotographerIds != null &&
          followedPhotographerIds.isNotEmpty) {
        params['followed_photographer_ids'] = followedPhotographerIds;
      }

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
      debugPrint(
          '[Discovery] DioException: ${err.message} | status: ${err.response?.statusCode} | body: ${err.response?.data}');
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
      final res = await _api.dio.get(
        '/photographer/events/$eventId/images',
        queryParameters: {'page': 1, 'limit': 25},
      );
      final raw = res.data;
      final Map<String, dynamic> data;
      if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
        data = raw['data'] as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        data = raw;
      } else {
        throw const app_ex.ServerException('Unexpected event response format');
      }
      debugPrint('[Discovery] getEventById raw keys: ${data.keys.toList()}');
      debugPrint('[Discovery] getEventById raw: $data');

      // This endpoint pages the pictures at the top level and puts the event
      // beside them, while EventDiscovery looks for them *inside* the event —
      // so without folding them in, every event fetched by id came back with
      // an empty album, and anything that opened one opened nothing.
      final rawEvent = data['event'];
      if (rawEvent is Map<String, dynamic>) {
        final merged = Map<String, dynamic>.from(rawEvent);
        if (merged['pictures'] == null && merged['images'] == null) {
          final pictures = data['data'];
          if (pictures is List) merged['pictures'] = pictures;
        }
        debugPrint(
            '[Discovery] getEventById folded ${(merged['pictures'] as List?)?.length ?? 0} picture(s)');
        return EventDiscovery.fromMap(merged);
      }
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
      for (final key in [
        'data',
        'events',
        'results',
        'items',
        'randomImages',
        'randomEvents'
      ]) {
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
