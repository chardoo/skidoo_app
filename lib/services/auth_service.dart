import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores all user session data in the OS-level secure enclave:
///  • iOS  → Keychain (inaccessible to other apps and backups by default)
///  • Android → EncryptedSharedPreferences backed by the Keystore
///
/// Nothing sensitive is written to SharedPreferences.
class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ── Storage keys ────────────────────────────────────────────────────────────
  static const _kToken = 'auth.access_token';
  static const _kExpiration = 'auth.token_expiration';
  static const _kUniqueName = 'auth.unique_name';
  static const _kEmail = 'auth.email';
  static const _kId = 'auth.user_id';
  static const _kName = 'auth.user_name';

  // ── Token ────────────────────────────────────────────────────────────────────
  Future<void> setToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<String> getToken() async =>
      await _storage.read(key: _kToken) ?? '';

  // ── Expiration ───────────────────────────────────────────────────────────────
  /// Stores the ISO-8601 expiration string returned by the server.
  Future<void> setExpiration(String iso) =>
      _storage.write(key: _kExpiration, value: iso);

  Future<String> getExpiration() async =>
      await _storage.read(key: _kExpiration) ?? '';

  /// Returns true when a token exists but its expiration date has already
  /// passed.  If no expiration was stored the token is treated as valid.
  Future<bool> isTokenExpired() async {
    final token = await getToken();
    if (token.isEmpty) return true;
    final exp = await getExpiration();
    if (exp.isEmpty) return false;
    try {
      return DateTime.now().isAfter(DateTime.parse(exp));
    } catch (_) {
      return false;
    }
  }

  // ── Profile fields ───────────────────────────────────────────────────────────
  Future<void> setUniqueName(String v) =>
      _storage.write(key: _kUniqueName, value: v);

  Future<String> getUniqueName() async =>
      await _storage.read(key: _kUniqueName) ?? '';

  Future<void> setEmail(String v) =>
      _storage.write(key: _kEmail, value: v);

  Future<String> getEmail() async =>
      await _storage.read(key: _kEmail) ?? '';

  Future<void> setId(String v) =>
      _storage.write(key: _kId, value: v);

  Future<String> getUserId() async =>
      await _storage.read(key: _kId) ?? '';

  Future<void> setName(String v) =>
      _storage.write(key: _kName, value: v);

  Future<String> getName() async =>
      await _storage.read(key: _kName) ?? '';

  // ── Session teardown ─────────────────────────────────────────────────────────
  /// Deletes every auth key individually so non-auth preferences are untouched.
  Future<void> removeToken() => Future.wait([
        _storage.delete(key: _kToken),
        _storage.delete(key: _kExpiration),
        _storage.delete(key: _kUniqueName),
        _storage.delete(key: _kEmail),
        _storage.delete(key: _kId),
        _storage.delete(key: _kName),
      ]);
}
