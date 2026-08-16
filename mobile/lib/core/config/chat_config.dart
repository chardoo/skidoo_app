/// Configuration for the chat micro-service.
/// Change [restBaseUrl] / [wsBaseUrl] to point at the production host.
class ChatConfig {
  ChatConfig._();

  static const String restBaseUrl = 'https://photoapp-backend-ka5m.onrender.com';
  static const String wsBaseUrl = 'https://photoapp-backend-ka5m.onrender.com';

  /// Roles recognised by the chat service.
  static const String roleClient = 'client';
  static const String rolePhotographer = 'photographer';

  /// Default page size for message history.
  static const int messagePageSize = 30;

  /// Whether outgoing messages are end-to-end encrypted.
  ///
  /// Turned off deliberately. New messages are sent in plaintext, which is what
  /// lets the server produce the inbox preview line the redesign draws under
  /// each room name — the server cannot preview what it cannot read.
  ///
  /// Decryption is deliberately *not* gated on this: see [e2eeDecryptEnabled].
  /// The whole key exchange (X3DH for DMs, sender keys for groups) is still
  /// here and still wired up, so turning this back on is a one-line change
  /// rather than an archaeology exercise.
  ///
  /// What this being false means: messages sent from now on are readable by the
  /// server and by anyone with database access.
  static const bool e2eeEnabled = false;

  /// Whether stored ciphertext is still decrypted on read.
  ///
  /// Stays true independently of [e2eeEnabled]. Every message sent while
  /// encryption was on is still ciphertext in the database, and the keys for it
  /// are still on the device — so turning decryption off too would blank out
  /// users' entire history behind "Encrypted message", including in the new
  /// previews. Old conversations keep opening normally; only new sends change.
  static const bool e2eeDecryptEnabled = true;
}
