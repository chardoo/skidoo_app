import 'package:jperg_app/core/deep_links/deep_link.dart';

/// The public domain the app's links live on.
///
/// Must match `PUBLIC_WEB_URL` on the backend and the `applinks:` entry in
/// `ios/Runner/Runner.entitlements` / `deepLinkHost` in `build.gradle.kts`.
/// A link built on any other host opens a browser instead of the app, and
/// nothing reports an error when it does — so this is the one place the value
/// is written on the client.
class AppLinksConfig {
  AppLinksConfig._();

  static const String shareBaseUrl = 'https://jperg.com';

  /// The URL a share should carry for [link].
  ///
  /// Built from [DeepLink.path] rather than assembled by hand, so anything the
  /// app shares is by construction something [parseDeepLink] can read back.
  static String urlFor(DeepLink link) => '$shareBaseUrl${link.path()}';
}
