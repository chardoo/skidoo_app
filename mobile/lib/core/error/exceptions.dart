class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'A server error occurred.']);
  @override
  String toString() => message;
}

/// A [ServerException] that kept the status and error code the server sent.
///
/// Without these the only thing a caller could do was search the formatted
/// message for a status code — which read "400" out of a body that merely
/// contained it, and mistook "you cannot DM yourself" for "this user is not
/// accepting messages". The codes are the API's own vocabulary; use them.
class ApiException extends ServerException {
  const ApiException(super.message, {this.statusCode, this.code});

  final int? statusCode;

  /// `error.code` from the response body — e.g. RECIPIENT_NOT_ACCEPTING_DMS.
  final String? code;
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'No internet connection.']);
  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Unauthorized. Please log in.']);
  @override
  String toString() => message;
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Local storage error.']);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Resource not found.']);
  @override
  String toString() => message;
}

class BadRequestException implements Exception {
  final String message;
  const BadRequestException([this.message = 'Invalid request.']);
  @override
  String toString() => message;
}

/// Login was rejected because the account's email hasn't been verified yet
/// (backend: 403, error.code == "EMAIL_NOT_VERIFIED").
class EmailNotVerifiedException implements Exception {
  final String message;
  const EmailNotVerifiedException(
      [this.message = 'Please verify your email address to continue.']);
  @override
  String toString() => message;
}
