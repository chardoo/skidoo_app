import 'package:jperg_app/core/error/exceptions.dart';

/// Why a conversation would not open, in words worth showing someone.
///
/// Every caller used to decide this by asking whether the formatted error
/// mentioned "400", which got it backwards in both directions: the real
/// "not accepting messages" answer is a 403, and the 400 it did catch was
/// "you cannot start a DM with yourself". The server names each case; this
/// reads the name.
String chatErrorText(Object error, {required String fallback}) {
  if (error is NetworkException) return 'No connection. Try again.';
  if (error is! ApiException) return fallback;
  switch (error.code) {
    case 'RECIPIENT_NOT_ACCEPTING_DMS':
      return 'This user is not accepting new conversations.';
    case 'USER_BLOCKED':
      return 'You cannot message this user.';
    default:
      return fallback;
  }
}
