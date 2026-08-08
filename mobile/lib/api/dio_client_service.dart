import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
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
