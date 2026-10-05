import 'package:dio/dio.dart' as dio;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_exceptions;

abstract class UserProfileRemoteDataSource {
  /// Fetches the canonical profile for [clientId] from the backend.
  /// Returns a normalised map with the app's camelCase keys.
  Future<Map<String, dynamic>> getProfile(String clientId);
}

class UserProfileRemoteDataSourceImpl implements UserProfileRemoteDataSource {
  final Api _api;
  UserProfileRemoteDataSourceImpl(this._api);

  @override
  Future<Map<String, dynamic>> getProfile(String clientId) async {
    try {
      final res = await _api.dio.get('/client/profile/$clientId');
      if (res.statusCode == 200 && res.data is Map) {
        return _normalise(Map<String, dynamic>.from(res.data as Map));
      }
      throw app_exceptions.ServerException(
          'Profile fetch failed. Status: ${res.statusCode}');
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_exceptions.NetworkException();
      throw app_exceptions.ServerException(
          'Profile fetch failed: ${err.response?.statusCode}');
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      throw app_exceptions.ServerException(
          'Unexpected profile fetch error: $e');
    }
  }

  /// The backend may nest the client object and uses snake_case keys; accept
  /// both snake_case and camelCase so we are resilient to either shape.
  Map<String, dynamic> _normalise(Map<String, dynamic> raw) {
    // Some endpoints wrap the entity under `data`/`client`/`user`.
    final m = (raw['data'] ?? raw['client'] ?? raw['user'] ?? raw)
        as Map<String, dynamic>;

    String pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    List<String> pickList(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is List) return v.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return {
      'name': pick(['name']),
      'email': pick(['email']),
      // Dropped here until now, which is why the app only ever knew a profile
      // picture it had just uploaded itself: the endpoint returns this on
      // every fetch, and nothing downstream ever saw it.
      'profileUrl': pick(['profile_url', 'profileUrl']),
      // `username` first, and `uiqueName` only behind it. The second is the
      // face-recognition person id, which the server sets to the account's
      // email for everyone who did not sign up as a photographer — so reading
      // it as the handle put an email address under the avatar. `username` is
      // the column that exists to be a handle; the fallbacks are for a build
      // talking to a server from before it.
      'uniqueName':
          pick(['username', 'uniqueName', 'uiqueName', 'unique_name']),
      'contact': pick(['contact', 'phone']),
      'countryCode': pick(['countryCode', 'country_code']),
      'locale': pick(['locale', 'region']),
      'preferredLanguage':
          pick(['preferredLanguage', 'preferred_language', 'language']),
      'timezone': pick(['timezone', 'time_zone']),
      'interestTags':
          pickList(['interestTags', 'interest_tags', 'interests', 'tags']),
    };
  }
}
