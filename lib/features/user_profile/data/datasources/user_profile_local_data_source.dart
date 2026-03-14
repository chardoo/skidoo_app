import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/services/auth_service.dart';

abstract class UserProfileLocalDataSource {
  Future<String> getName();
  Future<String> getEmail();
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
  Future<void> clearSession() async {
    try {
      await _authService.removeToken();
    } catch (e) {
      throw CacheException('Failed to clear session: $e');
    }
  }
}
