import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/config/chat_config.dart';

/// Two names for one kind of account.
///
/// The app calls a non-photographer a *client* — in its models, its screens and
/// the sessions it has already stored on people's phones. The chat service
/// calls the same account a *user*, which is also what the JWT says and what
/// every role check over there compares against, and it accepts nothing else.
///
/// Sending the app's word straight through is what made starting a DM with an
/// ordinary account fail with a 422 while messaging a photographer worked: the
/// only recipients whose role happened to spell the same on both sides were
/// photographers.
void main() {
  test('an ordinary account goes on the wire as the service names it', () {
    expect(ChatConfig.wireRole(ChatConfig.roleClient), 'user');
  });

  test('a photographer is the one role both sides already agree on', () {
    expect(
      ChatConfig.wireRole(ChatConfig.rolePhotographer),
      ChatConfig.rolePhotographer,
    );
  });

  test('a role that is already the service\'s word survives untouched', () {
    // Some of these come from the server (a search result, a message sender)
    // and are already canonical. Translating twice must not change them.
    expect(ChatConfig.wireRole('user'), 'user');
  });

  test('anything else is an ordinary account, not a role to be trusted', () {
    // The alternative is passing an unknown string through to a participant
    // row, and a participant row claiming "superAdmin" is what makes an account
    // unblockable — see the chat service's ParticipantRoleField. Photographer
    // is the one elevation this can grant, and it takes the exact word.
    for (final role in ['superAdmin', 'Admin', 'Photographer', '']) {
      expect(ChatConfig.wireRole(role), 'user', reason: role);
    }
  });
}
