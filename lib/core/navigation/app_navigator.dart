import 'package:flutter/material.dart';

/// Global navigator key — registered on [MaterialApp] so that the Dio
/// interceptor can trigger a login redirect without needing a [BuildContext].
class AppNavigator {
  AppNavigator._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static void navigateToLogin() {
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
