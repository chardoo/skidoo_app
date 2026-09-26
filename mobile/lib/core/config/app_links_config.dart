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

  /// The creator dashboard, which lives on the web rather than in the app.
  ///
  /// Built on [shareBaseUrl] rather than written out, so it cannot drift from
  /// the public domain the way the hardcoded Render preview URL it replaced
  /// had — that one still pointed at picco-v2.onrender.com.
  static const String creatorDashboardUrl =
      '$shareBaseUrl/photographer/dashboard';

  /// Where a new creator goes to put their first photos up.
  ///
  /// The photo library, not an `/upload` page: on the web an upload belongs to
  /// an event, so there is nowhere to put a file until one exists. This used to
  /// point at `/upload`, which is not a route the site has — the button on
  /// "you're ready" opened the site's own 404 page, which is a poor first
  /// impression of a portal somebody has just signed up for.
  static const String creatorUploadUrl = '$shareBaseUrl/photographer/events';

  /// The URL a share should carry for [link].
  ///
  /// Built from [DeepLink.path] rather than assembled by hand, so anything the
  /// app shares is by construction something [parseDeepLink] can read back.
  static String urlFor(DeepLink link) => '$shareBaseUrl${link.path()}';
}
