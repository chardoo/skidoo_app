import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  ThemeCubit(this._prefs)
      : super(
          _prefs.getString(_key) == 'light' ? ThemeMode.light : ThemeMode.dark,
        );

  bool get isDark => state == ThemeMode.dark;

  void toggleTheme() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _prefs.setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
    emit(next);
  }
}
