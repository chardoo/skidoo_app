import 'dart:io';

import 'package:skidoo_app/models/Auth/LoginResponse.dart';

abstract class AuthRepository {
  Future<LoginResponseObject> login(String email, String password);
  Future<void> register(Map<String, String> fields, File image);
  Future<void> saveUserSession(LoginResponseObject user);
  Future<String> getToken();
  Future<void> logout();
  Future<void> updateProfile(String clientId, Map<String, dynamic> data);
  Future<void> setPendingInterests();
  Future<bool> isPendingInterests();
  Future<void> clearPendingInterests();
}
