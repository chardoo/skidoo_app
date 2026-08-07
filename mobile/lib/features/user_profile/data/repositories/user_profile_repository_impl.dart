import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/user_profile/data/datasources/user_profile_local_data_source.dart';
import 'package:jperg_app/features/user_profile/data/datasources/user_profile_remote_data_source.dart';
import 'package:jperg_app/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:jperg_app/services/auth_service.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileLocalDataSource _localDataSource;
  final UserProfileRemoteDataSource _remoteDataSource;
  final AuthService _authService;
  UserProfileRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._authService,
  );

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
    // Local cache is the always-available baseline.
    final Map<String, dynamic> local;
    try {
      local = await _localDataSource.getFullProfile();
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Failed to load profile: $e');
    }

    // Try to refresh from the backend so fields edited on another session (or
    // lost from local storage after a re-login) are restored. Any failure
    // (no endpoint / offline / unexpected shape) silently keeps the local copy.
    try {
      final clientId = await _authService.getUserId();
      if (clientId.isEmpty) return local;
      final remote = await _remoteDataSource.getProfile(clientId);

      // Merge: a non-empty remote value wins; otherwise keep the local value.
      final merged = Map<String, dynamic>.from(local);
      remote.forEach((key, value) {
        final isEmptyString = value is String && value.isEmpty;
        final isEmptyList = value is List && value.isEmpty;
        if (value != null && !isEmptyString && !isEmptyList) {
          merged[key] = value;
        }
      });

      // Write the refreshed values back to the local cache so they persist.
      await _localDataSource.updateLocalProfile(merged);
      return merged;
    } catch (_) {
      return local;
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
