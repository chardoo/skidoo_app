/// Where the app's requests go.
///
/// One constant, because the host was written out three times — the Dio
/// client, the chat REST client and the chat socket — and three copies of a
/// value that must agree is three chances for them not to. They are reached
/// through the same gateway and there is no arrangement in which only one of
/// them should move.
///
/// [host] is the gateway, which fans out to every service behind it: `/api`
/// to main, `/chat` and `/chat/ws` to chat, and so on. Pointing the app at a
/// different deployment is this line.
class ApiConfig {
  ApiConfig._();

  /// The gateway, with no trailing slash and no path.
  ///
  /// Production. It was `photoapp-backend-ka5m.onrender.com`, which is the
  /// deployment the app was built against and not the one its users are meant
  /// to reach.
  static const String host = 'https://api.piccotechnologies.com';

  /// Main's routes, which all sit under `/api` — see the prefix every router
  /// in that service is registered with.
  static const String apiBaseUrl = '$host/api';

  /// The socket scheme for [host].
  ///
  /// Derived rather than written down a second time: an `https` host whose
  /// socket was left as `ws` fails the upgrade, and the two being separate
  /// strings is exactly how that happens.
  static String get wsHost =>
      host.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
}
