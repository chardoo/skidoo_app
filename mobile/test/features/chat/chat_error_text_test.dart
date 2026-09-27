import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';

/// What somebody is told when a conversation will not open.
///
/// Every failure used to come out as the caller's fallback — "Could not open
/// the conversation" for a recipient who is not accepting DMs, for a room the
/// service refused, and for a chat service that was simply down. Five words
/// covering three different problems, none of which the reader could act on,
/// and a bug report that could not be told apart from any other.
///
/// Two things were wrong. The refusal path threw a bare `ServerException`,
/// which carries no code, so the one message this formatter exists to produce
/// was unreachable. And the formatter ignored `serverMessage` — the server's
/// own words, written for a person — even when it had them.
void main() {
  const fallback = 'Could not open the conversation.';

  group('the cases worth wording ourselves', () {
    test('a recipient who is not accepting DMs is named as such', () {
      // The server states this for an API. "RECIPIENT_NOT_ACCEPTING_DMS" is
      // not a sentence to put in a snackbar.
      final message = chatErrorText(
        const ApiException('refused',
            statusCode: 403, code: 'RECIPIENT_NOT_ACCEPTING_DMS'),
        fallback: fallback,
      );
      expect(message, 'This user is not accepting new conversations.');
    });

    test('a block is named as such', () {
      final message = chatErrorText(
        const ApiException('refused', statusCode: 403, code: 'USER_BLOCKED'),
        fallback: fallback,
      );
      expect(message, 'You cannot message this user.');
    });

    test('a known code wins over the server text', () {
      // Both present: the code is the one we have written a human sentence
      // for, so it takes precedence.
      final message = chatErrorText(
        const ApiException(
          'refused',
          statusCode: 403,
          code: 'USER_BLOCKED',
          serverMessage: 'Blocked.',
        ),
        fallback: fallback,
      );
      expect(message, 'You cannot message this user.');
    });
  });

  group('everything else the server explains', () {
    test('its own sentence reaches the reader', () {
      // The defect this file exists for: the server said why, and the app
      // replaced it with five generic words.
      final message = chatErrorText(
        const ApiException(
          'Chat API error 400: …',
          statusCode: 400,
          serverMessage: 'You cannot start a conversation with yourself.',
        ),
        fallback: fallback,
      );
      expect(message, 'You cannot start a conversation with yourself.');
    });

    test('a blank server message is not shown as a blank snackbar', () {
      final message = chatErrorText(
        const ApiException('boom', statusCode: 400, serverMessage: '   '),
        fallback: fallback,
      );
      expect(message, fallback);
    });
  });

  group('when the server says nothing quotable', () {
    test('a refusal does not advise trying again', () {
      // "Please try again" is wrong advice for a 403 — nothing about trying
      // again changes the answer.
      final message = chatErrorText(
        const ApiException('denied', statusCode: 403),
        fallback: fallback,
      );
      expect(message, 'You cannot open this conversation.');
    });

    test('an outage does advise trying again, because it is true', () {
      final message = chatErrorText(
        const ApiException('boom', statusCode: 503),
        fallback: fallback,
      );
      expect(message, contains('try again'));
    });

    test('anything else falls back to the caller\'s words', () {
      final message = chatErrorText(
        const ApiException('odd', statusCode: 418),
        fallback: fallback,
      );
      expect(message, fallback);
    });
  });

  test('no connection is said plainly', () {
    expect(
      chatErrorText(const NetworkException(), fallback: fallback),
      'No connection. Try again.',
    );
  });

  test('a bare ServerException still falls back', () {
    // It carries no code and no server text, so there is nothing better to
    // say. The fix was to stop *throwing* one of these where a code existed —
    // see GetOrCreateDirectRoomUseCase.
    expect(
      chatErrorText(const ServerException('x'), fallback: fallback),
      fallback,
    );
  });
}
