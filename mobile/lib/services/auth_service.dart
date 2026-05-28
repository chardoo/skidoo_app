import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-adaptive credential store.
///
/// • Mobile (iOS/Android): [FlutterSecureStorage] → Keychain / EncryptedSharedPreferences.
/// • Web: [SharedPreferences] → localStorage.
///   FlutterSecureStorage uses the Web Crypto API which requires a secure
///   context (HTTPS) and throws OperationError on plain HTTP dev servers.
///   localStorage is the best available option on web — the token is already
///   visible to any JS on the page, so there is no meaningful security
///   difference between the two on that platform.
class AuthService {
  // ── Global auth state ────────────────────────────────────────────────────────
  /// Synchronous, reactive indicator of whether the current session has a
  /// valid token.  Updated by [setToken] (true) and [removeToken] (false).
  /// Seeded from the persisted token in main.dart before [runApp] is called.
  /// Used by the web sidebar to show the correct nav without an async check.
  static final isAuthenticated = ValueNotifier<bool>(false);

  // ── Mobile backend ───────────────────────────────────────────────────────────
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Web backend cache ────────────────────────────────────────────────────────
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _webPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ── Storage keys ─────────────────────────────────────────────────────────────
  static const _kToken             = 'auth.access_token';
  static const _kExpiration        = 'auth.token_expiration';
  static const _kUniqueName        = 'auth.unique_name';
  static const _kEmail             = 'auth.email';
  static const _kId                = 'auth.user_id';
  static const _kName              = 'auth.user_name';
  static const _kPendingInterests  = 'auth.pending_interests';
  static const _kContact           = 'auth.contact';
  static const _kCountryCode       = 'auth.country_code';
  static const _kLocale            = 'auth.locale';
  static const _kPreferredLanguage = 'auth.preferred_language';
  static const _kTimezone          = 'auth.timezone';
  static const _kInterestTags      = 'auth.interest_tags';
  static const _kRole              = 'auth.role';

  // ── Adaptive helpers ─────────────────────────────────────────────────────────

  Future<void> _write(String key, String? value) async {
    if (kIsWeb) {
      final p = await _webPrefs;
      if (value == null) {
        await p.remove(key);
      } else {
        await p.setString(key, value);
      }
    } else {
      await _secure.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final p = await _webPrefs;
      return p.getString(key);
    } else {
      return _secure.read(key: key);
    }
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final p = await _webPrefs;
      await p.remove(key);
    } else {
      await _secure.delete(key: key);
    }
  }

  // ── Token ────────────────────────────────────────────────────────────────────
  Future<void> setToken(String token) {
    isAuthenticated.value = token.isNotEmpty;
    return _write(_kToken, token);
  }

  Future<String> getToken() async => await _read(_kToken) ?? '';

  // ── Expiration ───────────────────────────────────────────────────────────────
  Future<void> setExpiration(String iso) => _write(_kExpiration, iso);

  Future<String> getExpiration() async => await _read(_kExpiration) ?? '';

  /// Returns true when a token exists but its expiration date has already
  /// passed. If no expiration was stored the token is treated as valid.
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

  // ── Profile fields ────────────────────────────────────────────────────────────
  Future<void> setUniqueName(String v) => _write(_kUniqueName, v);
  Future<String> getUniqueName() async => await _read(_kUniqueName) ?? '';

  Future<void> setEmail(String v) => _write(_kEmail, v);
  Future<String> getEmail() async => await _read(_kEmail) ?? '';

  Future<void> setId(String v) => _write(_kId, v);
  Future<String> getUserId() async => await _read(_kId) ?? '';

  Future<void> setName(String v) => _write(_kName, v);
  Future<String> getName() async => await _read(_kName) ?? '';

  // ── Extended profile fields ───────────────────────────────────────────────────
  Future<void> setContact(String v) => _write(_kContact, v);
  Future<String> getContact() async => await _read(_kContact) ?? '';

  Future<void> setCountryCode(String v) => _write(_kCountryCode, v);
  Future<String> getCountryCode() async => await _read(_kCountryCode) ?? '';

  Future<void> setLocale(String v) => _write(_kLocale, v);
  Future<String> getLocale() async => await _read(_kLocale) ?? '';

  Future<void> setPreferredLanguage(String v) => _write(_kPreferredLanguage, v);
  Future<String> getPreferredLanguage() async =>
      await _read(_kPreferredLanguage) ?? '';

  Future<void> setTimezone(String v) => _write(_kTimezone, v);
  Future<String> getTimezone() async => await _read(_kTimezone) ?? '';

  Future<void> setInterestTags(List<String> tags) =>
      _write(_kInterestTags, tags.join(','));

  Future<List<String>> getInterestTags() async {
    final raw = await _read(_kInterestTags) ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  // ── Pending interests flag ────────────────────────────────────────────────────
  Future<void> setPendingInterests() => _write(_kPendingInterests, '1');

  Future<bool> isPendingInterests() async =>
      (await _read(_kPendingInterests)) == '1';

  Future<void> clearPendingInterests() => _delete(_kPendingInterests);

  // ── Role ─────────────────────────────────────────────────────────────────────
  Future<void> setRole(String role) => _write(_kRole, role);
  Future<String> getRole() async => await _read(_kRole) ?? '';
  Future<bool> isSuperAdmin() async => (await getRole()) == 'super_admin';

  // ── Session teardown ──────────────────────────────────────────────────────────
  /// Deletes every auth key so non-auth preferences are untouched.
  Future<void> removeToken() {
    isAuthenticated.value = false;
    return Future.wait([
      _delete(_kToken),
      _delete(_kExpiration),
      _delete(_kUniqueName),
      _delete(_kEmail),
      _delete(_kId),
      _delete(_kName),
      _delete(_kContact),
      _delete(_kCountryCode),
      _delete(_kLocale),
      _delete(_kPreferredLanguage),
      _delete(_kTimezone),
      _delete(_kInterestTags),
      _delete(_kRole),
    ]);
  }
}
