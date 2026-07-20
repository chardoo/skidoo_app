import 'dart:typed_data';

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
    } on EmailNotVerifiedException {
      rethrow;
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
  Future<void> register(Map<String, String> fields, Uint8List? imageBytes, String? imageFilename) async {
    try {
      await _remoteDataSource.register(fields, imageBytes, imageFilename);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error during registration: $e');
    }
  }

  @override
  Future<LoginResponseObject> verifyCode(Map<String, dynamic> data) async {
    try {
      return await _remoteDataSource.verifyCode(data);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error during code verification: $e');
    }
  }

  @override
  Future<void> resendVerification(String email) async {
    try {
      await _remoteDataSource.resendVerification(email);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error during resend: $e');
    }
  }

  @override
  Future<void> becomePhotographer() async {
    try {
      await _remoteDataSource.becomePhotographer();
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error during photographer upgrade: $e');
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
        _authService.setHasAddedFaces(user.hasAddedFaces),
        if (user.role.isNotEmpty) _authService.setRole(user.role),
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
  Future<void> requestPasswordReset(String email) async {
    try {
      await _remoteDataSource.requestPasswordReset(email);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error requesting a reset code: $e');
    }
  }

  @override
  Future<void> verifyResetCode(String email, String code) async {
    try {
      await _remoteDataSource.verifyResetCode(email, code);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error verifying the reset code: $e');
    }
  }

  @override
  Future<void> resetPassword(String email, String code, String password) async {
    try {
      await _remoteDataSource.resetPassword(email, code, password);
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error resetting the password: $e');
    }
  }

  @override
  Future<void> setPendingInterests() => _authService.setPendingInterests();

  @override
  Future<bool> isPendingInterests() => _authService.isPendingInterests();

  @override
  Future<void> clearPendingInterests() => _authService.clearPendingInterests();
}
