import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/app_readiness.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/navigation/app_navigator.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/review_photographers_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_navigation_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:jperg_app/features/search/domain/usecases/search_usecase.dart';
import 'package:jperg_app/features/search/presentation/pages/search_event_photos_page.dart';
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
    // Held until the app has finished choosing its own first screen. The splash
    // navigates with pushReplacement 1.2–6s after launch, which replaces the
    // top of the stack — so a link followed before that is opened and then
    // silently discarded, landing the person on whatever the splash chose.
    // Waiting also puts a real destination underneath, so Back works.
    if (!AppReadiness.isReady.value) {
      debugPrint('$_tag holding $link until the app has started');
      _pending = link;
      return;
    }

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
        debugPrint('$_tag pushing resolver for $link');
        await navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'deeplink/resolver'),
            builder: (_) => DeepLinkTarget(link: link),
          ),
        );
        // Completes when the resolver (or whatever replaced it) is popped —
        // so this line means the person has navigated back off the link.
        debugPrint('$_tag resolver route for $link popped');
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
    // Deferred to after the frame, and this is the difference between the app
    // working and the app being unusable.
    //
    // initState runs while this very route is being pushed, so the navigator is
    // locked. `_resolve` is async but only suspends at its first `await`, and
    // the event case has none before it navigates — so it called
    // `pushReplacement` inside that locked span. The assertion it throws fires
    // *between* the navigator setting `_debugLocked` and clearing it, so the
    // flag is never reset: the Navigator stays locked for the rest of the
    // session and every later pop asserts. That is why a deep link left the app
    // unable to navigate anywhere at all, rather than just failing to open the
    // link.
    //
    // Deferring the whole method rather than that one branch keeps the next
    // case that forgets an `await` from doing the same thing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resolve();
    });
  }

  /// Swap *this* route for [destination].
  ///
  /// Not `pushReplacement`: that replaces whichever route is topmost, which is
  /// only this one if nothing has been pushed since. This screen exists because
  /// a fetch is in flight, and anything can arrive during it — so when the guess
  /// is wrong it replaces someone else's route and leaves this one in the stack
  /// forever, still loading. Back then lands on a spinner that can never
  /// finish, with a bare app bar and no way to tell what it is.
  ///
  /// `replace` names the route to swap, so it is exact wherever this sits.
  /// `pushReplacement` is kept for the common case only because it animates.
  void _swapSelfFor(Route<void> destination) {
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route == null) {
      navigator.push(destination);
      return;
    }
    if (route.isCurrent) {
      navigator.pushReplacement(destination);
      return;
    }

    // Something landed on top of us while the fetch was in flight — on a cold
    // start that is the splash arriving at its own destination, which is the
    // guest feed when the session has not resolved yet.
    //
    // Replacing in place is not enough: it puts the link's destination *under*
    // the interloper, so the person taps a link to an album and is left looking
    // at the feed. That is the "it opened and I'm not logged in" report — the
    // album was there the whole time, one route down.
    //
    // So take this route out of the stack and put the destination on top. The
    // link the person tapped is the thing they asked for, and it should win.
    debugPrint('$_tag resolver was overtaken — removing it and surfacing the '
        'destination on top');
    navigator.removeRoute(route);
    navigator.push(destination);
  }

  Future<void> _resolve() async {
    final link = widget.link;
    debugPrint('$_tag resolver running for $link');
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
          _swapSelfFor(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'deeplink/request'),
              builder: (_) => ReviewPhotographersPage(request: request),
            ),
          );
          return;

        // The album page takes an id and fetches the rest itself, so a link
        // needs nothing but what it already carries.
        case DeepLinkKind.event:
          if (!mounted) {
            debugPrint('$_tag resolver unmounted before opening the album — '
                'something replaced it');
            return;
          }
          debugPrint('$_tag opening album ${link.id}');
          _swapSelfFor(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'deeplink/album'),
              builder: (_) => SearchEventPhotosPage(eventId: link.id!),
            ),
          );
          return;

        // A photo is always shown inside its album — there is no screen that
        // takes a bare picture id, and inventing one would be a second viewer
        // to keep in step. So the id is resolved to its event first, and the
        // link opens the album with the viewer already on that photo. Two
        // screens are pushed so Back leaves the person in the album rather
        // than straight out of the app.
        case DeepLinkKind.picture:
          final photo = await sl<SearchUseCase>().picture(link.id!);
          if (!mounted) return;
          final navigator = Navigator.of(context);
          final viewer = MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'deeplink/photo'),
            builder: (_) => FoundPhotoViewerPage(photos: [photo]),
          );

          if (photo.eventId.isEmpty) {
            _swapSelfFor(viewer);
            return;
          }

          // This route becomes the album, then the viewer goes on top of it, so
          // Back leaves the person in the album rather than straight out of the
          // app. The viewer is not awaited — the future a push returns completes
          // when that route is *popped*, so awaiting it here would block until
          // they had already left.
          _swapSelfFor(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'deeplink/album'),
              builder: (_) => SearchEventPhotosPage(eventId: photo.eventId),
            ),
          );
          unawaited(navigator.push(viewer));
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
    // Says what it is. A bare app bar over a spinner is indistinguishable from
    // a broken screen — there was no way to tell whether the link was still
    // loading, had failed, or had landed somewhere unexpected.
    return Scaffold(
      appBar: AppBar(title: const Text('Opening link')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Opening…', textAlign: TextAlign.center),
                  ],
                )
              : Text(_error ?? '', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
