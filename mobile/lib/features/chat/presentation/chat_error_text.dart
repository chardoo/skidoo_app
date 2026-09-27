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

  // The codes first: these two are worth wording ourselves, because the server
  // states them for an API rather than for the person reading a snackbar.
  switch (error.code) {
    case 'RECIPIENT_NOT_ACCEPTING_DMS':
      return 'This user is not accepting new conversations.';
    case 'USER_BLOCKED':
      return 'You cannot message this user.';
  }

  // Then whatever the server actually said.
  //
  // It was going straight to the fallback before, which is how every failure
  // on the Message button came out as "Could not open the conversation" — the
  // same five words for a recipient who cannot be reached, a room the service
  // refused to create, and a chat service that was simply down. The server
  // writes these to be read; `uploadErrorText` beside this already prefers
  // them for the same reason.
  final serverSaid = error.serverMessage?.trim();
  if (serverSaid != null && serverSaid.isNotEmpty) return serverSaid;

  // Nothing quotable. Say which way it failed rather than repeating one
  // sentence for every cause — "please try again" is wrong advice for a 403
  // and right for a 500, and the two are worth telling apart.
  final status = error.statusCode;
  if (status == 401 || status == 403) {
    return 'You cannot open this conversation.';
  }
  if (status != null && status >= 500) {
    return 'Messaging is unavailable right now. Please try again shortly.';
  }
  return fallback;
}

/// Why an attachment would not upload, in words worth showing someone.
///
/// Prefers the server's own sentence. It is the only party that knows which of
/// the several possible reasons applied — over the size cap, an unsupported
/// type, storage not configured — and it already writes them for a reader.
/// Everything used to collapse into "Failed to upload image", which told the
/// user nothing and left no way to tell the causes apart from a bug report.
String uploadErrorText(Object error, {required bool isVideo}) {
  final kind = isVideo ? 'video' : 'image';
  final aKind = isVideo ? 'a video' : 'an image';
  if (error is NetworkException) {
    return 'No connection — the $kind was not sent.';
  }
  if (error is ApiException) {
    final serverSaid = error.serverMessage?.trim();
    if (serverSaid != null && serverSaid.isNotEmpty) return serverSaid;
    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'You are not signed in to send $aKind.';
    }
  }
  return 'Could not upload the $kind. Please try again.';
}
