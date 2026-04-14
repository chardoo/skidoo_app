import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_exceptions;
import 'package:skidoo_app/models/Auth/LoginResponse.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponseObject> login(String email, String password);
  Future<void> register(Map<String, String> fields, File image);
  Future<LoginResponseObject> confirmEmail(Map<String, dynamic> data);
  Future<LoginResponseObject> verifyCode(Map<String, dynamic> data);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Api _api;
  AuthRemoteDataSourceImpl(this._api);

  @override
  Future<LoginResponseObject> login(String email, String password) async {
    try {
      final res = await _api.dio.post(
        '/client/login',
        data: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode == 200) {
        return LoginResponseObject.fromJson(res.data as Map<String, dynamic>);
      }
      throw app_exceptions.ServerException(
          'Login failed. Status: ${res.statusCode}');
    } on dio.DioException catch (err) {
      throw _mapDioException(err);
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      throw const app_exceptions.ServerException('Unexpected login error.');
    }
  }

  @override
  Future<void> register(Map<String, String> fields, File image) async {
    try {
      final formData = dio.FormData.fromMap({
        ...fields,
        'files': await dio.MultipartFile.fromFile(
          image.path,
          filename: image.path.split('/').last,
        ),
      });
      final res = await _api.dio.post('/client/create', data: formData);
      if (res.statusCode == 201) return;
      throw app_exceptions.ServerException(
          'Registration failed. Status: ${res.statusCode}');
    } on dio.DioException catch (err) {
      throw _mapDioException(err);
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      throw const app_exceptions.NetworkException('Registration request failed.');
    }
  }

  @override
  Future<LoginResponseObject> confirmEmail(Map<String, dynamic> data) async {
    try {
      final res = await _api.dio.post(
        '/client/confirm-email',
        data: jsonEncode(data),
      );
      if (res.statusCode == 200) {
        return LoginResponseObject.fromJson(res.data as Map<String, dynamic>);
      }
      throw const app_exceptions.ServerException('Email confirmation failed.');
    } on dio.DioException catch (err) {
      throw _mapDioException(err);
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      throw const app_exceptions.ServerException('Unexpected error.');
    }
  }

  @override
  Future<LoginResponseObject> verifyCode(Map<String, dynamic> data) async {
    try {
      final res = await _api.dio.post(
        '/client/verify-code',
        data: jsonEncode(data),
      );
      if (res.statusCode == 200) {
        return LoginResponseObject.fromJson(res.data as Map<String, dynamic>);
      }
      throw const app_exceptions.ServerException('Code verification failed.');
    } on dio.DioException catch (err) {
      throw _mapDioException(err);
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      throw const app_exceptions.ServerException('Unexpected error.');
    }
  }

  Exception _mapDioException(dio.DioException err) {
    if (err.response == null) return const app_exceptions.NetworkException();
    final status = err.response?.statusCode;
    if (status == 401) return const app_exceptions.UnauthorizedException();
    if (status == 400) return const app_exceptions.BadRequestException();
    if (status == 404) return const app_exceptions.NotFoundException();
    return app_exceptions.ServerException('Server error. Status: $status');
  }
}
