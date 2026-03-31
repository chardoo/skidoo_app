import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefsService {
  static const _keyMuted = 'notifications_muted';

  final SharedPreferences _prefs;

  NotificationPrefsService(this._prefs);

  bool get isMuted => _prefs.getBool(_keyMuted) ?? false;

  Future<void> setMuted(bool value) => _prefs.setBool(_keyMuted, value);
}
