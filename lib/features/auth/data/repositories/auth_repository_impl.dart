import 'dart:io';

import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:skidoo_app/models/Auth/LoginResponse.dart';
import 'package:skidoo_app/services/auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthService _authService;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthService authService,
  })  : _remoteDataSource = remoteDataSource,
        _authService = authService;

  @override
  Future<LoginResponseObject> login(String email, String password) async {
    try {
      return await _remoteDataSource.login(email, password);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error during login: $e');
    }
  }

  @override
  Future<void> register(Map<String, String> fields, File image) async {
    try {
      await _remoteDataSource.register(fields, image);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error during registration: $e');
    }
  }

  @override
  Future<void> saveUserSession(LoginResponseObject user) async {
    try {
      await Future.wait([
        _authService.setToken(user.token),
        _authService.setUniqueName(user.uniqueName),
        _authService.setId(user.id),
        _authService.setEmail(user.email),
        _authService.setName(user.name),
        if (user.expiration.isNotEmpty)
          _authService.setExpiration(user.expiration),
      ]);
    } catch (e) {
      throw CacheException('Failed to save session: $e');
    }
  }

  @override
  Future<String> getToken() async {
    try {
      return await _authService.getToken();
    } catch (e) {
      throw CacheException('Failed to get token: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _authService.removeToken();
    } catch (e) {
      throw CacheException('Failed to log out: $e');
    }
  }

  @override
  Future<void> updateProfile(String clientId, Map<String, dynamic> data) async {
    try {
      await _remoteDataSource.updateProfile(clientId, data);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error during profile update: $e');
    }
  }

  @override
  Future<void> setPendingInterests() => _authService.setPendingInterests();

  @override
  Future<bool> isPendingInterests() => _authService.isPendingInterests();

  @override
  Future<void> clearPendingInterests() => _authService.clearPendingInterests();
}
