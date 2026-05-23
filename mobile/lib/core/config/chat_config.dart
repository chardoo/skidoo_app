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
}
