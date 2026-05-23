import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/services/auth_service.dart';

abstract class UserProfileLocalDataSource {
  Future<String> getName();
  Future<String> getEmail();
  Future<Map<String, dynamic>> getFullProfile();
  Future<void> updateLocalProfile(Map<String, dynamic> data);
  Future<void> clearSession();
}

class UserProfileLocalDataSourceImpl implements UserProfileLocalDataSource {
  final AuthService _authService;
  UserProfileLocalDataSourceImpl(this._authService);

  @override
  Future<String> getName() async {
    try {
      return await _authService.getName();
    } catch (e) {
      throw CacheException('Failed to get name: $e');
    }
  }

  @override
  Future<String> getEmail() async {
    try {
      return await _authService.getEmail();
    } catch (e) {
      throw CacheException('Failed to get email: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getFullProfile() async {
    try {
      final results = await Future.wait([
        _authService.getName(),
        _authService.getEmail(),
        _authService.getUniqueName(),
        _authService.getContact(),
        _authService.getCountryCode(),
        _authService.getLocale(),
        _authService.getPreferredLanguage(),
        _authService.getTimezone(),
        _authService.getInterestTags(),
      ]);
      return {
        'name': results[0],
        'email': results[1],
        'uniqueName': results[2],
        'contact': results[3],
        'countryCode': results[4],
        'locale': results[5],
        'preferredLanguage': results[6],
        'timezone': results[7],
        'interestTags': results[8],
      };
    } catch (e) {
      throw CacheException('Failed to load profile: $e');
    }
  }

  @override
  Future<void> updateLocalProfile(Map<String, dynamic> data) async {
    try {
      final futures = <Future>[];
      if (data.containsKey('name')) {
        futures.add(_authService.setName(data['name'] as String));
      }
      if (data.containsKey('uniqueName')) {
        futures.add(_authService.setUniqueName(data['uniqueName'] as String));
      }
      if (data.containsKey('contact')) {
        futures.add(_authService.setContact(data['contact'] as String));
      }
      if (data.containsKey('countryCode')) {
        futures.add(_authService.setCountryCode(data['countryCode'] as String));
      }
      if (data.containsKey('locale')) {
        futures.add(_authService.setLocale(data['locale'] as String));
      }
      if (data.containsKey('preferredLanguage')) {
        futures.add(_authService.setPreferredLanguage(data['preferredLanguage'] as String));
      }
      if (data.containsKey('timezone')) {
        futures.add(_authService.setTimezone(data['timezone'] as String));
      }
      if (data.containsKey('interestTags')) {
        futures.add(_authService.setInterestTags(
            List<String>.from(data['interestTags'] as List)));
      }
      await Future.wait(futures);
    } catch (e) {
      throw CacheException('Failed to save profile: $e');
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await _authService.removeToken();
    } catch (e) {
      throw CacheException('Failed to clear session: $e');
    }
  }
}
