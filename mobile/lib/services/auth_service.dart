import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jperg_app/services/push_notification_service.dart';

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

  /// Reactive mirror of `has_added_faces` — the same attribute the backend
  /// returns on login.
  ///
  /// Exists because the flag changes from screens that are nowhere near the
  /// ones that depend on it: deleting face data happens on the account page,
  /// while the Found tab lives in a keep-alive IndexedStack and would
  /// otherwise go on showing matches until the next app launch. Anything that
  /// gates on a face should listen here rather than read once.
  ///
  /// Seeded from storage at startup and kept in step by [setHasAddedFaces].
  static final hasAddedFaces = ValueNotifier<bool>(false);

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
  static const _kHasAddedFaces     = 'auth.has_added_faces';
  static const _kLastFacePrompt    = 'auth.last_face_prompt';
  static const _kHasSeenOnboarding = 'auth.has_seen_onboarding';
  static const _kHasSeenSwipeHint  = 'auth.has_seen_swipe_hint';
  static const _kAudiencePreference = 'auth.audience_preference';
  static const _kInstallMarker     = 'auth.install_marker';
  static const _kLastAccountId     = 'auth.last_account_id';

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

  // ── Face / reference photos prompt ────────────────────────────────────────────
  /// Whether the user has uploaded their reference photos (from login response).
  Future<void> setHasAddedFaces(bool v) {
    hasAddedFaces.value = v;
    return _write(_kHasAddedFaces, v.toString());
  }
  Future<bool> getHasAddedFaces() async =>
      (await _read(_kHasAddedFaces)) == 'true';

  /// Timestamp the "add your photos" prompt was last shown — used to re-show it
  /// only every few days.
  Future<void> setLastFacePrompt(DateTime when) =>
      _write(_kLastFacePrompt, when.toIso8601String());
  Future<DateTime?> getLastFacePrompt() async {
    final raw = await _read(_kLastFacePrompt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

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

  // ── Onboarding ───────────────────────────────────────────────────────────────
  /// Device-level flag (not cleared on logout) — the 3-screen intro carousel
  /// is shown once ever, not on every logged-out cold start.
  Future<void> setHasSeenOnboarding() => _write(_kHasSeenOnboarding, 'true');
  Future<bool> getHasSeenOnboarding() async =>
      (await _read(_kHasSeenOnboarding)) == 'true';

  /// The last account to hold a session on this device.
  ///
  /// Deliberately **not** cleared by [removeToken]: it is what tells the next
  /// sign-in whether it is the same person coming back or somebody new, and
  /// that question only has an answer if the marker outlives the session.
  /// [getUserId] cannot serve this purpose — logout deletes it, so after a
  /// logout every login looked like a first login and the account-switch wipe
  /// never ran, leaving one user's chat history on screen for the next.
  ///
  /// Keyed on the account id rather than the email so that changing an email
  /// keeps the same person's data, while a fresh sign-up (always a new id)
  /// wipes.
  Future<void> setLastAccountId(String id) => _write(_kLastAccountId, id);
  Future<String> getLastAccountId() async =>
      await _read(_kLastAccountId) ?? '';

  /// Device-level flag for the feed's swipe-up hint, shown once ever.
  ///
  /// Device-level rather than per-account, and deliberately grouped with
  /// [setHasSeenOnboarding]: the hint teaches a *gesture*, which someone only
  /// needs to learn once on this phone — not again after signing up, and not
  /// again on each new account.
  Future<void> setHasSeenSwipeHint() => _write(_kHasSeenSwipeHint, 'true');
  Future<bool> getHasSeenSwipeHint() async =>
      (await _read(_kHasSeenSwipeHint)) == 'true';

  /// "I'm here to discover" vs "Share my work" — a local content-personalisation
  /// signal only, does not change the account's role.
  Future<void> setAudiencePreference(String preference) =>
      _write(_kAudiencePreference, preference);
  Future<String> getAudiencePreference() async =>
      await _read(_kAudiencePreference) ?? '';

  // ── Session teardown ──────────────────────────────────────────────────────────
  /// Deletes every auth key so non-auth preferences are untouched.
  ///
  /// Detaching from OneSignal happens here rather than at the call sites
  /// because there are five of them (web sidebar, account page, the Dio 401
  /// interceptor, the logout use case). A path that cleared the token without
  /// detaching would leave the device attached to the old account, and the
  /// next person to sign in on this phone would receive their notifications.
  Future<void> removeToken() async {
    isAuthenticated.value = false;
    await PushNotificationService.instance.logout();
    await Future.wait([
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

  // ── Fresh-install detection ───────────────────────────────────────────────────
  /// On iOS, Keychain entries (what [FlutterSecureStorage] uses) survive app
  /// deletion — only the sandboxed container (SharedPreferences) is actually
  /// wiped on uninstall. Without this check, a "fresh install" silently
  /// inherits the previous install's token/onboarding-seen/etc. from the
  /// Keychain and looks like a returning user.
  ///
  /// [_kInstallMarker] itself lives in SharedPreferences (not Keychain), so
  /// it reads back false exactly once per real install, on every platform.
  Future<bool> isFreshInstall() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kInstallMarker) ?? false);
  }

  Future<void> markInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInstallMarker, true);
  }

  /// Wipes every key this service persists — the superset of [removeToken]
  /// (which deliberately keeps onboarding/faces state across a logout).
  /// Only call this when [isFreshInstall] is true.
  /// No longer called at startup — see the note in `main()`. A fresh install
  /// preserves the session and lets the server reject the token if it is no
  /// longer valid, because "SharedPreferences is empty" also describes every
  /// reinstall and every bundle-id change, and wiping on those signed people
  /// out for no reason. Kept for an explicit "forget this device" action.
  Future<void> resetAllForFreshInstall() async {
    isAuthenticated.value = false;
    hasAddedFaces.value = false;
    await Future.wait([
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
      _delete(_kHasAddedFaces),
      _delete(_kLastFacePrompt),
      _delete(_kHasSeenOnboarding),
      _delete(_kHasSeenSwipeHint),
      _delete(_kLastAccountId),
      _delete(_kAudiencePreference),
      _delete(_kPendingInterests),
    ]);
  }
}
