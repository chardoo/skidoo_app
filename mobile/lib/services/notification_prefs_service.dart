import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefsService {
  static const _keyMuted = 'notifications_muted';
  static const _keyAlwaysPublic = 'publication_always_public';

  final SharedPreferences _prefs;

  NotificationPrefsService(this._prefs);

  bool get isMuted => _prefs.getBool(_keyMuted) ?? false;
  Future<void> setMuted(bool value) => _prefs.setBool(_keyMuted, value);

  bool get alwaysPublicImages => _prefs.getBool(_keyAlwaysPublic) ?? false;
  Future<void> setAlwaysPublicImages(bool value) =>
      _prefs.setBool(_keyAlwaysPublic, value);

  /// Forget both settings when the session ends.
  ///
  /// Neither is a property of the phone; both are answers one person gave.
  /// Left standing they became the next person's answers on the same device:
  ///
  /// * `notifications_muted` — someone who had turned push off handed that to
  ///   whoever signed in next, who then received nothing and had a
  ///   "Push notifications" switch sitting at off they never touched.
  /// * `publication_always_public` — a photographer's default for how their
  ///   uploads are published, silently applied to somebody else's photos.
  ///
  /// Cleared rather than defaulted, so the next account reads the same
  /// first-run values a fresh install would.
  Future<void> clearForSignOut() async {
    await _prefs.remove(_keyMuted);
    await _prefs.remove(_keyAlwaysPublic);
  }
}
