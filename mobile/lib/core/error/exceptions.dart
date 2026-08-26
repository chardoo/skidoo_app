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
  const ApiException(super.message, {this.statusCode, this.code, this.serverMessage});

  final int? statusCode;

  /// `error.code` from the response body — e.g. RECIPIENT_NOT_ACCEPTING_DMS.
  final String? code;

  /// `error.message` from the response body — the server's own words, written
  /// to be read by a person ("File exceeds the 10 MB limit for videos").
  ///
  /// Worth carrying separately from [message], which is a debug string with the
  /// status code and raw body baked in and is not fit to show anyone.
  final String? serverMessage;
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

/// Sign-up hit an account that already exists and can be used as-is
/// (backend: 409, error.code == "ACCOUNT_EXISTS").
///
/// Distinct from a bare 409 so the UI can offer the way out — the login
/// screen — rather than only reporting that the email or phone is taken.
class AccountExistsException implements Exception {
  const AccountExistsException(
    this.message, {
    this.email,
    this.field = 'email',
  });

  final String message;

  /// Present only when the *email* the user typed is the one on file, so
  /// echoing it back tells them nothing they did not just enter. Absent on a
  /// phone-number clash, where the account's address belongs to a different
  /// sign-up.
  final String? email;

  /// Which field collided: `email` or `contact`.
  final String field;

  @override
  String toString() => message;
}

/// Sign-up hit an existing account that never confirmed its email
/// (backend: 409, error.code == "ACCOUNT_EXISTS_UNVERIFIED").
///
/// Not an error the user can act on by changing what they typed: the account
/// is theirs and half-made. The backend has already re-sent the code, so the
/// only sensible response is to drop them into the verification step.
class AccountExistsUnverifiedException implements Exception {
  const AccountExistsUnverifiedException(this.message, {required this.email});

  final String message;

  /// The address the fresh code was sent to — addresses the verification
  /// screen and its own resend button.
  final String email;

  @override
  String toString() => message;
}
