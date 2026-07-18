import 'dart:typed_data';

import 'package:skidoo_app/models/Auth/LoginResponse.dart';

abstract class AuthRepository {
  Future<LoginResponseObject> login(String email, String password);
  Future<void> register(Map<String, String> fields, Uint8List? imageBytes, String? imageFilename);
  Future<LoginResponseObject> verifyCode(Map<String, dynamic> data);
  Future<void> resendVerification(String email);
  Future<void> saveUserSession(LoginResponseObject user);
  Future<String> getToken();
  Future<void> logout();
  Future<void> updateProfile(String clientId, Map<String, dynamic> data);
  Future<void> setPendingInterests();
  Future<bool> isPendingInterests();
  Future<void> clearPendingInterests();
  Future<void> becomePhotographer();
}
