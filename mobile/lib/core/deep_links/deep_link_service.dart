import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/navigation/app_navigator.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/review_photographers_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_navigation_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:jperg_app/models/photographer/photographerModel.dart';

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
    switch (link.kind) {
      // The viewer's own photos are a tab, not a route: land on Home, then ask
      // it for the Found tab. Both notifiers already exist for exactly this —
      // the sidebar and the search results page use them the same way.
      case DeepLinkKind.myPhotos:
        await navigator.pushNamedAndRemoveUntil(
          HomePage.routeName,
          (route) => false,
        );
        HomePage.tabRequest.value = 0; // Home column
        HomeNavigationPage.pillTabRequest.value = 0; // Found
        return;

      // The profile page fetches its own stats, samples and portfolio from the
      // id, so a link only has to carry that much. Name and avatar fill in
      // when it loads rather than being guessed from the URL.
      case DeepLinkKind.photographer:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => PhotographerProfilePage(
              photographer: PhotographerModel(link.id!, '', '', ''),
            ),
          ),
        );
        return;

      // Everything else is resolved first: the id in a link may be for
      // something deleted, closed, or never visible to this viewer, and
      // pushing a screen that then fails is worse than saying so.
      case DeepLinkKind.picture:
      case DeepLinkKind.event:
      case DeepLinkKind.request:
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => DeepLinkTarget(link: link)),
        );
        return;
    }
  }
}

/// Resolver for the links whose destination needs fetching first.
///
/// Shows the fetch, then either the thing or a plain "not available" — a dead
/// link is common (a request gets closed, a photo goes private) and it should
/// read as an answer rather than a broken screen.
class DeepLinkTarget extends StatefulWidget {
  const DeepLinkTarget({super.key, required this.link});

  final DeepLink link;

  @override
  State<DeepLinkTarget> createState() => _DeepLinkTargetState();
}

class _DeepLinkTargetState extends State<DeepLinkTarget> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final link = widget.link;
    try {
      switch (link.kind) {
        case DeepLinkKind.request:
          final request = await AdsRepository().getRequest(link.id!);
          if (!mounted) return;
          if (request == null) {
            setState(() {
              _loading = false;
              _error = 'This request is no longer available.';
            });
            return;
          }
          // Replaces itself so Back returns to where the link was tapped
          // rather than to a spinner that has nothing left to do.
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ReviewPhotographersPage(request: request),
            ),
          );
          return;

        // No screen takes an event or a single picture by id yet — the feed
        // builds both from a list it already holds. Rather than invent one,
        // this says so plainly; wiring it is a screen, not a resolver.
        case DeepLinkKind.event:
        case DeepLinkKind.picture:
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = 'Opening a single ${link.kind.name} from a link '
                'is not available yet.';
          });
          return;

        case DeepLinkKind.myPhotos:
        case DeepLinkKind.photographer:
          return; // handled without a resolver
      }
    } catch (e) {
      debugPrint('$_tag resolve ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not open that link.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ?? '',
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}
