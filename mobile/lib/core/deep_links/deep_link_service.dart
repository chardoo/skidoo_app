import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:skidoo_app/core/deep_links/deep_link.dart';
import 'package:skidoo_app/core/navigation/app_navigator.dart';

const _tag = '[DeepLinks]';

/// Receives links and opens what they point at.
///
/// Two arrivals, and they are not the same: a link that launched the app from
/// cold, and one that arrived while it was already running. The cold one is the
/// awkward case — it is there before the Navigator is, so it is held until the
/// first frame rather than dropped, which is the usual reason a link "works
/// when the app is open and does nothing when it is closed".
class DeepLinkService {
  DeepLinkService({AppLinks? links, Future<bool> Function()? isSignedIn})
      : _links = links ?? AppLinks(),
        _isSignedIn = isSignedIn;

  final AppLinks _links;
  final Future<bool> Function()? _isSignedIn;

  StreamSubscription<Uri>? _sub;

  /// A link that arrived before it could be followed — either before the
  /// Navigator existed, or before the person signed in. Kept so it can be
  /// resumed rather than lost, because the alternative is someone tapping a
  /// link in an email, being asked to sign in, and landing on a home screen
  /// with no idea what they were meant to see.
  DeepLink? _pending;

  DeepLink? get pending => _pending;

  Future<void> start() async {
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) {
        debugPrint('$_tag cold start ← $initial');
        await handle(initial);
      }
    } catch (e) {
      // A bad initial link must never stop the app from launching.
      debugPrint('$_tag initial link ERROR: $e');
    }

    _sub ??= _links.uriLinkStream.listen(
      (uri) {
        debugPrint('$_tag resumed ← $uri');
        handle(uri);
      },
      onError: (Object e) => debugPrint('$_tag stream ERROR: $e'),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Follow a link, or remember it until it can be followed.
  Future<void> handle(Uri uri) async {
    final link = parseDeepLink(uri);
    if (link == null) {
      // Not ours. The domain also serves a website, and opening the app on a
      // route it has no screen for is worse than leaving it in the browser.
      debugPrint('$_tag ignored (no screen for it): $uri');
      return;
    }
    await follow(link);
  }

  /// Open a link now if everything it needs is in place, or hold it.
  Future<void> follow(DeepLink link) async {
    final isSignedIn = _isSignedIn;
    if (link.requiresAuth && isSignedIn != null && !await isSignedIn()) {
      debugPrint('$_tag holding $link until sign-in');
      _pending = link;
      AppNavigator.navigateToLogin();
      return;
    }

    final navigator = AppNavigator.navigatorKey.currentState;
    if (navigator == null) {
      // The app is still starting. Held rather than dropped — resumePending()
      // runs once there is somewhere to navigate to.
      debugPrint('$_tag holding $link until the navigator exists');
      _pending = link;
      return;
    }

    _pending = null;
    debugPrint('$_tag opening $link');
    await _open(navigator, link);
  }

  /// Follow whatever was held, if anything. Safe to call repeatedly — after a
  /// sign-in, after the first frame, on resume.
  Future<void> resumePending() async {
    final link = _pending;
    if (link == null) return;
    _pending = null;
    await follow(link);
  }

  Future<void> _open(NavigatorState navigator, DeepLink link) async {
    // Every destination that needs data fetches it behind a resolver rather
    // than being handed an id it cannot render, so a link that turns out to be
    // dead says so instead of opening an empty screen.
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => DeepLinkTarget(link: link)),
    );
  }
}

/// Placeholder destination.
///
/// Deliberately explicit rather than silently landing on the home screen: an
/// unimplemented link should look unimplemented, to whoever is wiring the next
/// one, not like a link that quietly went nowhere.
class DeepLinkTarget extends StatelessWidget {
  const DeepLinkTarget({super.key, required this.link});

  final DeepLink link;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Opening ${link.kind.name}…')),
    );
  }
}
