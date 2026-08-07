import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Starts [DeepLinkService] and keeps it running for the life of the app.
///
/// The service handles cold starts by holding the link until a Navigator
/// exists, so this only has to exist above [MaterialApp] and call `start()`
/// once. Without it none of that code ever runs: the link opens the app and
/// the app opens whatever screen it would have opened anyway.
///
/// Not on web — there the URL bar *is* the router, and app_links has nothing
/// to listen to.
class DeepLinkHost extends StatefulWidget {
  const DeepLinkHost({super.key, required this.child});

  final Widget child;

  @override
  State<DeepLinkHost> createState() => _DeepLinkHostState();
}

class _DeepLinkHostState extends State<DeepLinkHost> {
  DeepLinkService? _service;
  VoidCallback? _authListener;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    // "Signed in" here means a token exists — deliberately NOT
    // AuthService.isAuthenticated, which is seeded in main() from the locally
    // stored expiry date. The API layer stopped trusting that date on purpose
    // (see AppInterceptors.onRequest: "Always send the token — let the server
    // decide if it has expired"), because a stale local expiration marks a
    // perfectly good session as dead. Reading the flag here reintroduced that
    // false negative on the one path that punishes it hardest: the link sends
    // the person to /login, which clears the whole navigation stack, so a
    // signed-in user tapping a link out of the "we found your photos" email is
    // told to sign in again. The token is never cleared, which is why it looks
    // like a spurious logout rather than an expired session.
    //
    // If the token really is dead the request behind the screen 401s, and the
    // interceptor handles it there with the server's answer rather than a guess.
    final service = DeepLinkService(
      isSignedIn: () async => (await sl<AuthService>().getToken()).isNotEmpty,
    );
    _service = service;

    // After the first frame: a link that launched the app from cold arrives
    // before the Navigator exists, and the service parks it. This is the
    // earliest point there is somewhere to send it.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await service.start();
      await service.resumePending();
    });

    // Someone tapping a link to their own photos while signed out is sent to
    // sign in first; this is what resumes the link afterwards instead of
    // leaving them on the home screen wondering what they were meant to see.
    _authListener = () {
      if (AuthService.isAuthenticated.value) service.resumePending();
    };
    AuthService.isAuthenticated.addListener(_authListener!);
  }

  @override
  void dispose() {
    if (_authListener != null) {
      AuthService.isAuthenticated.removeListener(_authListener!);
    }
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
