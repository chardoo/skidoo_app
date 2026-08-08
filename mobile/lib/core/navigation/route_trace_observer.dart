import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Logs every route change, so a navigation bug can be read rather than guessed.
///
/// Deep-link failures have all looked the same from the outside — "it opened
/// and then I was somewhere else" — because nothing recorded *what* arrived and
/// in which order. A push that lands a fraction of a second after another one
/// is invisible in the UI and obvious here.
///
/// Debug builds only: this is diagnostic, not product behaviour.
class RouteTraceObserver extends NavigatorObserver {
  static final RouteTraceObserver instance = RouteTraceObserver._();
  RouteTraceObserver._();

  /// Routes are mostly unnamed [MaterialPageRoute]s, so fall back to something
  /// identifiable. Give the routes you care about a `RouteSettings(name: …)`
  /// and they show up here by name.
  String _name(Route<dynamic>? route) {
    if (route == null) return '<none>';
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return route.runtimeType.toString();
  }

  void _log(String verb, Route<dynamic>? route, Route<dynamic>? other) {
    if (!kDebugMode) return;
    final from = other == null ? '' : ' (was ${_name(other)})';
    debugPrint('[Nav] $verb ${_name(route)}$from');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('push   ', route, previousRoute);

    // An unnamed route says nothing about itself, and ~58 places build one.
    //
    // The caller cannot be recovered from the stack: didPush runs from the
    // navigator's own history flush, so by the time we are called the frame
    // that pushed has long returned — StackTrace.current shows only this
    // observer. Identify the route by what it *renders* instead, one frame
    // later, once its subtree exists.
    if (!kDebugMode) return;
    if ((route.settings.name ?? '').isNotEmpty) return;
    if (route is! ModalRoute) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = route.subtreeContext;
      if (context is! Element) return;

      final names = <String>[];
      void visit(Element element) {
        if (names.length >= 3) return;
        final name = element.widget.runtimeType.toString();
        // App screens, not framework scaffolding.
        if (!name.startsWith('_') &&
            (name.endsWith('Page') ||
                name.endsWith('Screen') ||
                name.endsWith('View'))) {
          names.add(name);
        }
        element.visitChildren(visit);
      }

      context.visitChildren(visit);
      debugPrint('[Nav]   ↑ that unnamed route renders: '
          '${names.isEmpty ? "<nothing recognisable>" : names.join(" > ")}');
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log('pop    ', route, previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log('remove ', route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _log('replace', newRoute, oldRoute);
}
