import 'package:dio/dio.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Dedicated Dio client for the chat micro-service.
///
/// Injects the x-user-* headers expected by the chat service gateway on
/// every request. These headers are derived from the locally stored auth
/// credentials – no extra API call needed.
class ChatApiClient {
  final Dio _dio;

  ChatApiClient(AuthService authService) : _dio = _buildDio(authService);

  Dio get dio => _dio;

  static Dio _buildDio(AuthService authService) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ChatConfig.restBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(_ChatAuthInterceptor(authService));
    return dio;
  }
}

class _ChatAuthInterceptor extends Interceptor {
  final AuthService _authService;

  _ChatAuthInterceptor(this._authService);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _authService.getToken();
      final userId = await _authService.getUserId();
      final email = await _authService.getEmail();
      final name = await _authService.getName();
      final role = await _authService.getRole();

      if (token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      if (userId.isNotEmpty) {
        options.headers['x-user-id'] = userId;
        options.headers['x-user-email'] = email;
        // The chat gateway only recognises two roles (ChatConfig.roleClient /
        // rolePhotographer) — was hardcoded to roleClient for every account,
        // so a photographer's REST identity was always wrong on the wire.
        // That silently worked for non-photographers only because their
        // real auth role happens to fall through to the same default here.
        options.headers['x-user-role'] = role == ChatConfig.rolePhotographer
            ? ChatConfig.rolePhotographer
            : ChatConfig.roleClient;
        options.headers['x-user-name'] = name;
      }
    } catch (_) {
      // Proceed unauthenticated – server will return 401.
    }
    handler.next(options);
  }
}
