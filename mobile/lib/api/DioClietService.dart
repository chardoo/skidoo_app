import 'package:dio/dio.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/core/di/service_locator.dart';

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
      final token = await sl<AuthService>().getToken();
      if (token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // proceed without token if service locator not ready
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
