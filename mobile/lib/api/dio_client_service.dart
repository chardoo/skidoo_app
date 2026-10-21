import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/cache/block_sync.dart';
import 'package:jperg_app/core/cache/deleted_content.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/navigation/app_navigator.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/config/api_config.dart';

class Api {
  final dio = createDio();
  Api._internal();

  static final _singleton = Api._internal();
  factory Api() => _singleton;

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      validateStatus: (status) => status != null && status <= 399,
      baseUrl: ApiConfig.apiBaseUrl,
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

    // Tell the server how recently this device heard about blocked content, so
    // the answer can name whatever has been taken down since. Added here so
    // the dozen places that fetch events do not each have to remember.
    //
    // Scoped to the paths that read it rather than added to every GET: a
    // request can carry an absolute URL, and a stored asset URL is signed —
    // one extra query parameter on one of those is a broken signature and a
    // photo that will not load. See `_blockSyncPaths`.
    try {
      if (_wantsBlockSync(options)) {
        final since = BlockSync.watermark;
        if (since != null && since.isNotEmpty) {
          options.queryParameters = {
            ...options.queryParameters,
            'blockedSince': since,
          };
        }
      }
    } catch (_) {
      // A missing watermark only ever widens the answer. Never worth failing
      // the request the reader actually asked for.
    }

    handler.next(options);
  }

  /// Paths that read `blockedSince` and answer with a `blocked` block.
  ///
  /// `/api` optional for the same reason the like paths have it that way: not
  /// every caller builds a path against the same base.
  static final List<RegExp> _blockSyncPaths = [
    // An album's photo grid — the list most likely to be holding something
    // that has since been taken down.
    RegExp(r'^(?:/api)?/client/events/[^/]+/photos$'),
    // The dedicated sync, which sends the watermark itself but is matched here
    // so the two can never disagree about the parameter's name.
    RegExp(r'^(?:/api)?/client/blocked-content$'),
  ];

  static bool _wantsBlockSync(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    final clean = Uri.tryParse(options.path)?.path ?? options.path;
    return _blockSyncPaths.any((p) => p.hasMatch(clean));
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

  /// The endpoints that change what the signed-in user has liked.
  ///
  /// Here rather than at the call sites, and this is the point of it. The
  /// profile's Liked tab keeps its grid for the session and refetches only when
  /// [AppCacheSignals.likes] moves, so a like recorded without moving it is a
  /// like that does not appear on that screen until the app is restarted. That
  /// had happened three times over — the comment sheet's heart, and both of the
  /// chat room's — because each new way to like something had to remember a
  /// line that lives nowhere near it.
  ///
  /// Every like the app sends over HTTP goes through this interceptor, whatever
  /// layer sent it, so matching the path here covers the ones that exist and
  /// the ones nobody has written yet. The socket's half of the same rule is
  /// [ChatWebSocketService.sendLike] and the five senders beside it.
  ///
  /// `/api` optional: most paths are relative to a base URL that already
  /// carries it, but not every caller builds them the same way.
  static final List<RegExp> _likeChangingPaths = [
    // A photo: POST toggles, DELETE removes outright.
    RegExp(r'^(?:/api)?/chat/pictures/[^/]+/like$'),
    // An album: POST sets or clears the caller's reaction.
    RegExp(r'^(?:/api)?/chat/events/[^/]+/reaction$'),
  ];

  static bool _changesLikes(RequestOptions options) {
    if (options.method.toUpperCase() == 'GET') return false;
    final clean = Uri.tryParse(options.path)?.path ?? options.path;
    return _likeChangingPaths.any((p) => p.hasMatch(clean));
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Only on an answer the server actually gave. A failed like changed
    // nothing, and bumping would cost every liked grid a refetch to be told so.
    if (_changesLikes(response.requestOptions)) {
      AppCacheSignals.likes.bump();
    }

    // Blocked content, named on whatever request the app happened to be
    // making. Handled here rather than at each call site for the same reason
    // the 404 purge below is: there are a dozen places that fetch events and
    // one of them will always be the one nobody remembered to wire up. See
    // `BlockSync` — the work is a no-op unless the payload carries ids.
    //
    // Not awaited: the reader is waiting for this response, and pruning disk
    // caches is not something they should wait through. Failures inside are
    // swallowed and logged there.
    final body = response.data;
    if (body is Map && body['blocked'] != null) {
      unawaited(BlockSync.apply(body['blocked']));
    }

    handler.next(response);
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

/// Whether this request is one that changes what the user has liked.
///
/// Worth testing directly: it is the only thing that tells the profile's Liked
/// tab to fetch again, and a pattern that misses a real like endpoint puts the
/// "my like is not in my likes" bug straight back.
@visibleForTesting
bool changesLikesForTest(String method, String path) =>
    AppInterceptors._changesLikes(RequestOptions(path: path, method: method));

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
