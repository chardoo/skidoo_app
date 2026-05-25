import 'package:flutter/material.dart';

/// Singleton [NavigatorObserver] that tracks the current named route on web.
///
/// Used by [WebSidebar] to switch between logged-out and logged-in navigation
/// without coupling individual pages to the sidebar.
class WebRouteObserver extends NavigatorObserver {
  WebRouteObserver._();

  static final instance = WebRouteObserver._();

  /// The name of the currently active top-level named route.
  /// Set to the initial route by [_WebApp] on startup; updated on every
  /// [pushNamedAndRemoveUntil] / [pushReplacementNamed] call.
  static final currentRouteName = ValueNotifier<String?>(null);

  @override
  void didPush(Route route, Route? previousRoute) {
    final name = route.settings.name;
    if (name != null) currentRouteName.value = name;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    final name = previousRoute?.settings.name;
    if (name != null) currentRouteName.value = name;
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final name = newRoute?.settings.name;
    if (name != null) currentRouteName.value = name;
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    final name = previousRoute?.settings.name;
    if (name != null) currentRouteName.value = name;
  }
}
