import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
import 'package:skidoo_app/API/DioClietService.dart';
import 'package:skidoo_app/models/Auth/LoginResponse.dart';
import 'package:skidoo_app/models/badrequest.dart';

class AuthHttpService {
  Future<dynamic> login(Map<String, dynamic> requestData) async {
    try {
      final res = await Api().dio.post(
            '/client/login',
            data: jsonEncode(requestData),
          );
      switch (res.statusCode) {
        case 200:
          return LoginResponseObject.fromJson(res.data as Map<String, dynamic>);
        default:
          return BadRequest.fromMap(res.data as Map<String, dynamic>);
      }
    } on dio.DioException catch (err) {
      if (err.response == null) {
        throw Exception('No internet connection. Please try again.');
      }
      final statusCode = err.response?.statusCode;
      if (statusCode == 401) throw Exception('Invalid credentials.');
      if (statusCode == 400) throw Exception('Bad request. Check your input.');
      throw Exception('Login failed. Status: $statusCode');
    } catch (e) {
      throw Exception('An unexpected error occurred during login.');
    }
  }

  Future<bool> register(Map<String, String> requestData, File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://photoapp-backend-b71j.onrender.com/client/createClient'),
      );
      request.fields.addAll(requestData);
      request.files.add(http.MultipartFile(
        'images',
        file.readAsBytes().asStream(),
        file.lengthSync(),
        filename: file.path.split('/').last,
      ));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) return true;
      throw Exception(
          'Registration failed. Status: ${response.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unexpected error occurred during registration.');
    }
  }

  Future<dynamic> confirmEmail(Map<String, dynamic> requestData) async {
    try {
      final res = await Api().dio.post(
            '/client/confirmEmail',
            data: jsonEncode(requestData),
          );
      switch (res.statusCode) {
        case 200:
          return LoginResponseObject.fromJson(res.data as Map<String, dynamic>);
        default:
          return BadRequest.fromMap(res.data as Map<String, dynamic>);
      }
    } on dio.DioException catch (err) {
      if (err.response == null) {
        throw Exception('No internet connection.');
      }
      throw Exception('Email confirmation failed. Status: ${err.response?.statusCode}');
    }
  }

  Future<dynamic> verifyCode(Map<String, dynamic> requestData) async {
    try {
      final res = await Api().dio.post(
            '/client/confirmEmail',
            data: jsonEncode(requestData),
          );
      switch (res.statusCode) {
        case 200:
          return LoginResponseObject.fromJson(res.data as Map<String, dynamic>);
        default:
          return BadRequest.fromMap(res.data as Map<String, dynamic>);
      }
    } on dio.DioException catch (err) {
      if (err.response == null) {
        throw Exception('No internet connection.');
      }
      throw Exception('Code verification failed. Status: ${err.response?.statusCode}');
    }
  }
}
