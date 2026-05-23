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
  static const _kToken              = 'auth.access_token';
  static const _kExpiration         = 'auth.token_expiration';
  static const _kUniqueName         = 'auth.unique_name';
  static const _kEmail              = 'auth.email';
  static const _kId                 = 'auth.user_id';
  static const _kName               = 'auth.user_name';
  static const _kPendingInterests   = 'auth.pending_interests';
  static const _kContact            = 'auth.contact';
  static const _kCountryCode        = 'auth.country_code';
  static const _kLocale             = 'auth.locale';
  static const _kPreferredLanguage  = 'auth.preferred_language';
  static const _kTimezone           = 'auth.timezone';
  static const _kInterestTags       = 'auth.interest_tags';
  static const _kRole               = 'auth.role';

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

  // ── Extended profile fields ──────────────────────────────────────────────────
  Future<void> setContact(String v) => _storage.write(key: _kContact, value: v);
  Future<String> getContact() async => await _storage.read(key: _kContact) ?? '';

  Future<void> setCountryCode(String v) => _storage.write(key: _kCountryCode, value: v);
  Future<String> getCountryCode() async => await _storage.read(key: _kCountryCode) ?? '';

  Future<void> setLocale(String v) => _storage.write(key: _kLocale, value: v);
  Future<String> getLocale() async => await _storage.read(key: _kLocale) ?? '';

  Future<void> setPreferredLanguage(String v) => _storage.write(key: _kPreferredLanguage, value: v);
  Future<String> getPreferredLanguage() async => await _storage.read(key: _kPreferredLanguage) ?? '';

  Future<void> setTimezone(String v) => _storage.write(key: _kTimezone, value: v);
  Future<String> getTimezone() async => await _storage.read(key: _kTimezone) ?? '';

  /// Stored as comma-separated string for simplicity.
  Future<void> setInterestTags(List<String> tags) =>
      _storage.write(key: _kInterestTags, value: tags.join(','));

  Future<List<String>> getInterestTags() async {
    final raw = await _storage.read(key: _kInterestTags) ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  // ── Pending interests flag ───────────────────────────────────────────────────
  Future<void> setPendingInterests() =>
      _storage.write(key: _kPendingInterests, value: '1');

  Future<bool> isPendingInterests() async =>
      (await _storage.read(key: _kPendingInterests)) == '1';

  Future<void> clearPendingInterests() =>
      _storage.delete(key: _kPendingInterests);

  // ── Session teardown ─────────────────────────────────────────────────────────
  /// Deletes every auth key individually so non-auth preferences are untouched.
  Future<void> setRole(String role) => _storage.write(key: _kRole, value: role);
  Future<String> getRole() async => await _storage.read(key: _kRole) ?? '';
  Future<bool> isSuperAdmin() async => (await getRole()) == 'super_admin';

  Future<void> removeToken() => Future.wait([
        _storage.delete(key: _kToken),
        _storage.delete(key: _kExpiration),
        _storage.delete(key: _kUniqueName),
        _storage.delete(key: _kEmail),
        _storage.delete(key: _kId),
        _storage.delete(key: _kName),
        _storage.delete(key: _kContact),
        _storage.delete(key: _kCountryCode),
        _storage.delete(key: _kLocale),
        _storage.delete(key: _kPreferredLanguage),
        _storage.delete(key: _kTimezone),
        _storage.delete(key: _kInterestTags),
        _storage.delete(key: _kRole),
      ]);
}
