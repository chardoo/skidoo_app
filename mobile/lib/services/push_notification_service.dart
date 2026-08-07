import 'push_notification_service_stub.dart'
    if (dart.library.io) 'push_notification_service_io.dart' as impl;

/// OneSignal push notifications.
///
/// The backend addresses every push by *external user id*, and that id is
/// always `User.id` — the same value the JWT carries as `userId`, for clients
/// and photographers alike (there is no separate Client table). So the whole
/// contract on this side is: call [login] with `user.id` once a session is
/// established, and [logout] when it is torn down. Miss that and the backend's
/// sends still return 200, just with `recipients: 0` — nothing arrives and
/// nothing errors.
///
/// Every method is a no-op on web and desktop; only iOS and Android reach the
/// SDK. Nothing here throws — push failing must never take the app with it.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  /// How long to wait after sign-in before asking for notification permission,
  /// so the OS dialog lands on a settled screen rather than mid-render.
  static const Duration permissionPromptDelay = Duration(seconds: 3);

  /// Wires up the SDK and its listeners. Safe to call before sign-in — the
  /// device simply has no external id attached until [login] runs.
  Future<void> init() => impl.initPush();

  /// Asks for the OS notification permission. Kept separate from [init] so the
  /// prompt can be timed deliberately: iOS only ever lets you ask once, and
  /// asking a stranger on the splash screen converts far worse than asking
  /// someone who has just signed in.
  ///
  /// Returns false on web/desktop, on failure, or when the user declines.
  Future<bool> requestPermission() => impl.requestPushPermission();

  /// Attaches this device to [userId] so backend sends addressed to that
  /// external id reach it. [userId] must be the `id` from the login response.
  ///
  /// Idempotent — repeat calls with the same id do nothing, so this is safe on
  /// every app start as well as on an actual sign-in.
  Future<void> login(String userId) => impl.pushLogin(userId);

  /// Detaches the device from the current user. Called from
  /// `AuthService.removeToken`, so every logout path is covered — otherwise
  /// the next person to sign in on this phone would receive the previous
  /// account's notifications.
  Future<void> logout() => impl.pushLogout();
}
