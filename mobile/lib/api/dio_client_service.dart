import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/cache/deleted_content.dart';
import 'package:jperg_app/core/navigation/app_navigator.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';

class Api {
  final dio = createDio();
  Api._internal();

  static final _singleton = Api._internal();
  factory Api() => _singleton;

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      validateStatus: (status) => status != null && status <= 399,
      baseUrl: 'https://photoapp-backend-ka5m.onrender.com/api',
      receiveTimeout: const Duration(seconds: 60),
      connectTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    ));

    dio.interceptors.add(AppInterceptors(dio));
    return dio;
  }
}

class AppInterceptors extends Interceptor {
  final Dio dio;
  AppInterceptors(this.dio);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['Content-Type'] = 'application/json';
    try {
      final authService = sl<AuthService>();
      final token = await authService.getToken();
      // Always send the token — let the server decide if it has expired.
      // The local expiry check was causing false negatives after the WebView
      // checkout page kept the app in the background for an extended period.
      if (token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Proceed without token if service locator is not ready yet.
    }
    handler.next(options);
  }

  /// Event-scoped request paths, and where the id sits in them.
  ///
  /// An explicit list rather than a general "find a UUID in the path" rule:
  /// plenty of paths carry an id that is not an event's — a picture, a room, a
  /// photographer — and a 404 on one of those would otherwise evict an album
  /// that is perfectly alive.
  ///
  /// `/chat/rooms/event/{id}` is deliberately absent. It 404s when the room has
  /// not been created yet, which is the normal state of an album nobody has
  /// posted in, and that is not evidence about the album.
  static final List<RegExp> _eventScopedPaths = [
    // The grid behind an event row.
    RegExp(r'^/client/events/([^/]+)/photos$'),
    // The view ping the feed fires when someone opens an album.
    RegExp(r'^/recommend/([^/]+)/view$'),
  ];

  /// The event id this request was about, or null if it was not about one.
  static String? _eventIdIn(String path) {
    // Query string and host stripped: `path` is usually relative, but a caller
    // that passed an absolute URL would otherwise never match.
    final clean = Uri.tryParse(path)?.path ?? path;
    for (final pattern in _eventScopedPaths) {
      final match = pattern.firstMatch(clean);
      if (match != null) return Uri.decodeComponent(match.group(1) ?? '');
    }
    return null;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // A 404 on an event-scoped path is the only way the phone finds out an
    // album was deleted — there is no push for it, and the server simply stops
    // returning it. Ask every cache to drop it, or a cold launch keeps drawing
    // a card that opens on nothing. See `DeletedContent`.
    //
    // Deliberately not gated on 410: the server answers a deleted album exactly
    // as it answers an id that was never real, which is the right thing for it
    // to do and means 404 is all there is to go on. Forgetting an album that
    // 404'd for some other reason costs a refetch, and the id is re-cached the
    // moment the server returns it again.
    if (err.response?.statusCode == 404) {
      final eventId = _eventIdIn(err.requestOptions.path);
      if (eventId != null && !DeletedContent.alreadyForgotten(eventId)) {
        unawaited(DeletedContent.forgetEvent(eventId));
      }
    }

    if (err.response?.statusCode == 401) {
      // A 401 is not proof the session is dead.
      //
      // This used to clear credentials on *any* 401 from *any* endpoint, which
      // made one route-scoped rejection destroy a working session — and since
      // it also wipes the navigation stack to /login, the app simply appeared
      // logged out. A cold start fires many requests at once (config, feed,
      // chat, push registration), so it only takes one of them to answer 401
      // for the whole session to disappear. Opening a deep link is exactly that
      // burst, which is why it kept surfacing there.
      //
      // Real sources of a 401 that are NOT an expired session: the gateway
      // rejecting only /chat/* (proxy.py — every other route is forwarded
      // as-is), a client calling a photographer-only route, and any endpoint
      // that answers 401 where it means 403.
      //
      // So ask the token itself. Its `exp` claim is signed by the server and is
      // the only authority on whether this session is over — unlike the
      // separately stored expiration string, which drifts and which the request
      // interceptor above already refuses to trust.
      try {
        final authService = sl<AuthService>();
        final token = await authService.getToken();
        if (token.isNotEmpty && _isJwtExpired(token)) {
          await authService.removeToken();
          AppNavigator.navigateToLogin();
        } else if (token.isNotEmpty) {
          debugPrint(
            '[Auth] 401 from ${err.requestOptions.path} but the token has not '
            'expired — session kept. Treat this as a permission error.',
          );
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}

/// Whether the JWT's own `exp` claim has passed.
///
/// Returns false when the token cannot be read or carries no `exp`: an
/// unreadable token is not evidence of an ended session, and guessing wrong
/// signs someone out who was never logged out. A genuinely expired token always
/// has a readable `exp`, so nothing real is missed.
@visibleForTesting
bool isJwtExpiredForTest(String token) => _isJwtExpired(token);

/// Which album a 404'd request was about, or null if it was not about one.
///
/// Worth testing directly: this decides what gets evicted from a reader's
/// offline caches, and a pattern that is too generous throws away live albums
/// on a 404 that had nothing to do with them.
@visibleForTesting
String? eventIdInPathForTest(String path) => AppInterceptors._eventIdIn(path);

bool _isJwtExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return false;

    // base64url → base64, then pad to a multiple of 4.
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    payload = payload.padRight((payload.length + 3) & ~3, '=');

    final claims =
        jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
    final exp = claims['exp'];
    if (exp is! int) return false;

    return DateTime.now().toUtc().isAfter(
          DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
        );
  } catch (_) {
    return false;
  }
}
