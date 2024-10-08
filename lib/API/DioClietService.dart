import 'dart:async';

import "package:dio/dio.dart";


class Api {
  final dio = createDio();
  final tokenDio =
      Dio(BaseOptions(baseUrl: "https://photoapp-backend-b71j.onrender.com"));
  Api._internal();

  static final _singleton = Api._internal();

  factory Api() => _singleton;
 
  static Dio createDio() {
    var dio = Dio(BaseOptions(
      validateStatus: (status) {
        return status! <= 399;
      },
      baseUrl: "https://photoapp-backend-b71j.onrender.com",
      receiveTimeout: const Duration(seconds: 60000), // 15 seconds
      connectTimeout: const Duration(seconds: 60000),
      sendTimeout: const Duration(seconds: 60000),
    ));

    dio.interceptors.addAll({
      AppInterceptors(dio),
    });

    return dio;
  }
}

class AppInterceptors extends Interceptor {
  final Dio dio;
  AppInterceptors(this.dio);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['content-Type'] = 'application/json';
    
    // var token = await LocalStorage.getToken();

    // if (token.isNotEmpty) {
    //   options.data['token'] = token;
    // }

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // TODO: implement onResponse
    print("somethis is here man");
    super.onResponse(response, handler);
  }

  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    print("onError: $err jdjjsdsjjsddsj");
    if (err.response?.statusCode == null) {}
    return handler.next(err); // <--- THE TIP IS HERE
  }
}

class BadRequestException extends DioException {
  BadRequestException(RequestOptions r) : super(requestOptions: r);

  @override
  String toString() {
    return 'Invalid request';
  }
}

class InternalServerErrorException extends DioException {
  InternalServerErrorException(RequestOptions r) : super(requestOptions: r);

  @override
  String toString() {
    return 'Unknown error occurred, please try again later.';
  }
}

class ConflictException extends DioException {
  ConflictException(RequestOptions r) : super(requestOptions: r);

  @override
  String toString() {
    return 'Conflict occurred';
  }
}

class UnauthorizedException extends DioException {
  UnauthorizedException(RequestOptions r) : super(requestOptions: r);

  @override
  String toString() {
    return 'Access denied';
  }
}

class NotFoundException extends DioException {
  NotFoundException(RequestOptions r) : super(requestOptions: r);

  @override
  String toString() {
    return 'The requested information could not be found';
  }
}

class NoInternetConnectionException extends DioException {
  NoInternetConnectionException(RequestOptions r) : super(requestOptions: r);

  @override
  String toString() {
    return 'No internet connection detected, please try again.';
  }
}

class DeadlineExceededException extends DioException {
  DeadlineExceededException(RequestOptions r) : super(requestOptions: r);

  @override
  String toString() {
    return 'The connection has timed out, please try again.';
  }
}
