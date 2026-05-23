import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:http_parser/http_parser.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_exceptions;
import 'package:skidoo_app/models/Auth/LoginResponse.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponseObject> login(String email, String password);
  Future<void> register(Map<String, String> fields, File image);
  Future<LoginResponseObject> confirmEmail(Map<String, dynamic> data);
  Future<LoginResponseObject> verifyCode(Map<String, dynamic> data);
  Future<void> updateProfile(String clientId, Map<String, dynamic> data);
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
      final ext = image.path.split('.').last.toLowerCase();
      final mimeSubtype = (ext == 'jpg' || ext == 'jpeg') ? 'jpeg' : 'png';
      final multipart = await dio.MultipartFile.fromFile(
        image.path,
        filename: image.path.split('/').last,
        contentType: MediaType('image', mimeSubtype),
      );
      log('[register] fields: $fields');
      log('[register] image path: ${image.path}');
      log('[register] image exists: ${image.existsSync()}');
      log('[register] image size: ${image.lengthSync()} bytes');
      log('[register] multipart filename: ${multipart.filename}');
      log('[register] multipart contentType: ${multipart.contentType}');
      final formData = dio.FormData.fromMap({
        ...fields,
        'files': [multipart],
      });
      log('[register] formData fields: ${formData.fields.map((e) => '${e.key}=${e.value}').join(', ')}');
      log('[register] formData files: ${formData.files.map((e) => '${e.key}=${e.value.filename}').join(', ')}');
      final res = await _api.dio.post('/client/create', data: formData);
      log('[register] status=${res.statusCode} body=${res.data}');
      if (res.statusCode == 201) return;
      throw app_exceptions.ServerException(
          'Registration failed. Status: ${res.statusCode}');
    } on dio.DioException catch (err) {
      log('[register] DioException status=${err.response?.statusCode} body=${err.response?.data} message=${err.message}');
      throw _mapDioException(err);
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      log('[register] unexpected error: $e');
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

  @override
  Future<void> updateProfile(String clientId, Map<String, dynamic> data) async {
    try {
      final res = await _api.dio.patch(
        '/client/profile/$clientId',
        data: jsonEncode(data),
      );
      if (res.statusCode == 200) return;
      throw app_exceptions.ServerException(
          'Profile update failed. Status: ${res.statusCode}');
    } on dio.DioException catch (err) {
      throw _mapDioException(err);
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      throw const app_exceptions.ServerException('Unexpected profile update error.');
    }
  }

  Exception _mapDioException(dio.DioException err) {
    if (err.response == null) return const app_exceptions.NetworkException();
    final status = err.response?.statusCode;
    final serverMessage = _extractMessage(err.response?.data);
    if (status == 401) return const app_exceptions.UnauthorizedException();
    if (status == 400) {
      return app_exceptions.ServerException(
          serverMessage ?? 'Invalid request. Please check your details.');
    }
    if (status == 404) return const app_exceptions.NotFoundException();
    if (status == 409) {
      return app_exceptions.ServerException(
          serverMessage ?? 'An account with this email or contact already exists.');
    }
    return app_exceptions.ServerException(
        serverMessage ?? 'Server error. Status: $status');
  }

  String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final msg = data['message'] ?? data['detail'] ?? data['error'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }
}
