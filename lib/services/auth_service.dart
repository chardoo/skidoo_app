import 'package:shared_preferences/shared_preferences.dart';
import 'package:skidoo_app/core/di/service_locator.dart';

class AuthService {
  SharedPreferences get _prefs => sl<SharedPreferences>();

  Future<bool> setToken(String token) => _prefs.setString('access_token', token);

  Future<String> getToken() async => _prefs.getString('access_token') ?? '';

  Future<void> removeToken() => _prefs.clear();

  Future<bool> setUniqueName(String uniqueName) =>
      _prefs.setString('unique_name', uniqueName);

  Future<String> getUniqueName() async =>
      _prefs.getString('unique_name') ?? '';

  Future<bool> setEmail(String email) => _prefs.setString('email', email);

  Future<String> getEmail() async => _prefs.getString('email') ?? '';

  Future<bool> setId(String id) => _prefs.setString('id', id);

  Future<String> getUserId() async => _prefs.getString('id') ?? '';

  Future<bool> setName(String name) => _prefs.setString('name', name);

  Future<String> getName() async => _prefs.getString('name') ?? '';
}
