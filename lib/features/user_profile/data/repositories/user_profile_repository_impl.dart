import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/user_profile/data/datasources/user_profile_local_data_source.dart';
import 'package:skidoo_app/features/user_profile/domain/repositories/user_profile_repository.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileLocalDataSource _localDataSource;
  UserProfileRepositoryImpl(this._localDataSource);

  @override
  Future<String> getName() async {
    try {
      return await _localDataSource.getName();
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Failed to get name: $e');
    }
  }

  @override
  Future<String> getEmail() async {
    try {
      return await _localDataSource.getEmail();
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Failed to get email: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getFullProfile() async {
    try {
      return await _localDataSource.getFullProfile();
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Failed to load profile: $e');
    }
  }

  @override
  Future<void> updateLocalProfile(Map<String, dynamic> data) async {
    try {
      await _localDataSource.updateLocalProfile(data);
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Failed to save profile: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _localDataSource.clearSession();
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Logout failed: $e');
    }
  }
}
