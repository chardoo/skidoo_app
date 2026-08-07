import 'package:dio/dio.dart';
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
      // Session is genuinely expired on the server — clear local credentials
      // and send the user to the login screen so they can re-authenticate.
      try {
        final authService = sl<AuthService>();
        final token = await authService.getToken();
        if (token.isNotEmpty) {
          await authService.removeToken();
          AppNavigator.navigateToLogin();
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}
