class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'A server error occurred.']);
  @override
  String toString() => message;
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
