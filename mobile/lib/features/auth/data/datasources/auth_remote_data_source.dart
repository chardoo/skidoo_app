import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:http_parser/http_parser.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/error/exceptions.dart' as app_exceptions;
import 'package:skidoo_app/models/Auth/LoginResponse.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponseObject> login(String email, String password);
  Future<void> register(Map<String, String> fields, Uint8List? imageBytes, String? imageFilename);
  Future<LoginResponseObject> confirmEmail(Map<String, dynamic> data);
  Future<LoginResponseObject> verifyCode(Map<String, dynamic> data);
  Future<void> resendVerification(String email);
  Future<void> updateProfile(String clientId, Map<String, dynamic> data);
  Future<void> becomePhotographer();
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
  Future<void> register(Map<String, String> fields, Uint8List? imageBytes, String? imageFilename) async {
    try {
      dio.MultipartFile? multipart;
      if (imageBytes != null && imageFilename != null) {
        final ext = imageFilename.split('.').last.toLowerCase();
        final mimeSubtype = (ext == 'jpg' || ext == 'jpeg') ? 'jpeg' : 'png';
        multipart = dio.MultipartFile.fromBytes(
          imageBytes,
          filename: imageFilename,
          contentType: MediaType('image', mimeSubtype),
        );
      }
      log('[register] fields: $fields');
      log('[register] image filename: $imageFilename');
      final formData = dio.FormData.fromMap({
        ...fields,
        if (multipart != null) 'files': [multipart],
      });
      log('[register] formData fields: ${formData.fields.map((e) => '${e.key}=${e.value}').join(', ')}');
      log('[register] formData files: ${formData.files.map((e) => '${e.key}=${e.value.filename}').join(', ')}');
      final res = await _api.dio.post('/common/create', data: formData);
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
        '/client/verify-email',
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

  /// `POST /photographer/become` — authenticated, no body. Endpoint/response
  /// shape unconfirmed against the real backend (no doc exists for this yet,
  /// unlike e.g. the profile-photo opt-in) — any 2xx is treated as success.
  @override
  Future<void> becomePhotographer() async {
    try {
      final res = await _api.dio.post('/photographer/become');
      log('[becomePhotographer] status=${res.statusCode} body=${res.data}');
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
        return;
      }
      throw app_exceptions.ServerException(
          'Photographer upgrade failed. Status: ${res.statusCode}');
    } on dio.DioException catch (err) {
      log('[becomePhotographer] DioException status=${err.response?.statusCode} body=${err.response?.data}');
      throw _mapDioException(err);
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      log('[becomePhotographer] unexpected error: $e');
      throw const app_exceptions.NetworkException('Photographer upgrade request failed.');
    }
  }

  @override
  Future<void> resendVerification(String email) async {
    try {
      final res = await _api.dio.post(
        '/client/resend-verification',
        data: jsonEncode({'email': email}),
      );
      if (res.statusCode == 200) return;
      throw app_exceptions.ServerException(
          'Resend failed. Status: ${res.statusCode}');
    } on dio.DioException catch (err) {
      throw _mapDioException(err);
    } on app_exceptions.ServerException {
      rethrow;
    } catch (e) {
      throw const app_exceptions.NetworkException('Resend request failed.');
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
    final data = err.response?.data;
    final serverMessage = _extractMessage(data);
    if (status == 403 && _extractErrorCode(data) == 'EMAIL_NOT_VERIFIED') {
      return app_exceptions.EmailNotVerifiedException(
          serverMessage ?? 'Please verify your email address to continue.');
    }
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

  /// Handles both the standard envelope (`{success:false, error:{code,
  /// message, statusCode}}`) and older flatter shapes (`{message}`,
  /// `{detail}`, `{error: "..."}`).
  String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final nested = error['message'];
        if (nested is String && nested.isNotEmpty) return nested;
      }
      final msg = data['message'] ?? data['detail'] ?? (error is String ? error : null);
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }

  String? _extractErrorCode(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = error['code'];
        if (code is String) return code;
      }
    }
    return null;
  }
}
