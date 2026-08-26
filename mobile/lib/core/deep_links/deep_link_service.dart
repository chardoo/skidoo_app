import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/core/app_readiness.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/navigation/app_navigator.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/campaign_details_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/my_campaigns_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/request_board_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/photographer_booking_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/review_photographers_page.dart';
import 'package:jperg_app/features/cart/presentation/pages/cart_page.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';
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
        _isSignedIn = isSignedIn {
    instance = this;
  }

  /// The live service, for callers that arrive from outside the widget tree.
  ///
  /// A push tap is the one that needs this: OneSignal's click listener is
  /// registered in [initPush] long before — and quite independently of — the
  /// widget that owns this service, and on a cold start it fires while there
  /// is no context to look anything up from. Null until [DeepLinkHost] builds
  /// one, and on web, where the URL bar is the router and no host exists.
  ///
  /// Not the service locator: this is constructed by a widget rather than
  /// registered at startup, so it would have to be registered and unregistered
  /// around that widget's lifetime for `sl` to ever hold a live one.
  static DeepLinkService? instance;

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

  /// True while a link is waiting to be followed.
  ///
  /// Read by the splash, which otherwise holds the app for its brand beat and
  /// a feed warm-up before the first navigation — and a held link waits behind
  /// all of it. Someone who tapped a link is not waiting to see the feed load;
  /// this is what lets the splash cut itself short and hand over.
  ///
  /// Static because the splash is built by the route table and has no way to
  /// reach the instance, which is created by [DeepLinkHost] above the
  /// MaterialApp. It survives the service being disposed and rebuilt, which is
  /// why it is set from every path that parks a link rather than in one place.
  static final ValueNotifier<bool> isWaiting = ValueNotifier<bool>(false);

  void _park(DeepLink link) {
    _pending = link;
    isWaiting.value = true;
  }

  void _clearPending() {
    _pending = null;
    isWaiting.value = false;
  }

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
    if (identical(instance, this)) instance = null;
    // The flag is static and the link it stood for is going with this
    // instance, so leaving it raised would tell the next splash to hurry for
    // something no longer there.
    if (_pending != null) _clearPending();
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
      _park(link);
      return;
    }

    final isSignedIn = _isSignedIn;
    if (link.requiresAuth && isSignedIn != null && !await isSignedIn()) {
      debugPrint('$_tag holding $link until sign-in');
      _park(link);
      AppNavigator.navigateToLogin();
      return;
    }

    final navigator = AppNavigator.navigatorKey.currentState;
    if (navigator == null) {
      // The app is still starting. Held rather than dropped — resumePending()
      // runs once there is somewhere to navigate to.
      debugPrint('$_tag holding $link until the navigator exists');
      _park(link);
      return;
    }

    _clearPending();
    debugPrint('$_tag opening $link');
    await _open(navigator, link);
  }

  /// Follow whatever was held, if anything. Safe to call repeatedly — after a
  /// sign-in, after the first frame, on resume.
  Future<void> resumePending() async {
    final link = _pending;
    if (link == null) return;
    _clearPending();
    await follow(link);
  }

  /// Get to Home, without building a second one.
  ///
  /// On a cold start the splash has just landed on `/home`, and pushing a
  /// fresh one discards it and refetches everything it had already started —
  /// three blocs' worth, while the person watches. If a Home is live, come
  /// back to it instead; only build one when there genuinely isn't one, which
  /// is the signed-out case where the splash chose Discovery.
  Future<void> _toHome(NavigatorState navigator) async {
    if (HomePage.isLive) {
      debugPrint('$_tag reusing the Home already on screen');
      navigator.popUntil(
        (route) => route.settings.name == HomePage.routeName || route.isFirst,
      );
      return;
    }
    await navigator.pushNamedAndRemoveUntil(
      HomePage.routeName,
      (route) => false,
    );
  }

  Future<void> _open(NavigatorState navigator, DeepLink link) async {
    switch (link.kind) {
      // The viewer's own photos are a tab, not a route: land on Home, then ask
      // it for the Found tab. Both notifiers already exist for exactly this —
      // the sidebar and the search results page use them the same way.
      case DeepLinkKind.myPhotos:
        await _toHome(navigator);
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

      // ── Push-only destinations ───────────────────────────────────────────
      //
      // Tabs of the home screen rather than routes of their own, so each one
      // lands the same way myPhotos does: reset to Home, then ask it for the
      // tab. Pushing a second copy of a tab's page on top of the stack would
      // give the person a screen their bottom bar cannot get them out of.
      case DeepLinkKind.home:
        await _toHome(navigator);
        return;

      case DeepLinkKind.notifications:
        await _toHome(navigator);
        HomePage.tabRequest.value = 2; // Notifications
        return;

      // No room id — the messages list. With one, it falls through to the
      // resolver below, which fetches the room the page needs.
      case DeepLinkKind.chat when link.id == null:
        await _toHome(navigator);
        HomePage.tabRequest.value = 1; // Messages
        return;

      // There is no earnings screen in this app yet — the payout endpoints
      // exist, the UI does not. Profile is where a photographer goes looking
      // for it, so a cashout notification lands there rather than nowhere.
      // Point this at the real screen when it is built.
      case DeepLinkKind.earnings:
        await _toHome(navigator);
        HomePage.tabRequest.value = 3; // Profile
        return;

      case DeepLinkKind.adsDashboard:
        await navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'deeplink/campaigns'),
            builder: (_) => const MyCampaignsPage(),
          ),
        );
        return;

      case DeepLinkKind.requestBoard:
        await navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'deeplink/requests'),
            builder: (_) => const RequestBoardPage(),
          ),
        );
        return;

      case DeepLinkKind.cart:
        await navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'deeplink/cart'),
            builder: (_) => const CartPage(),
          ),
        );
        return;

      // Everything else is resolved first: the id in a link may be for
      // something deleted, closed, or never visible to this viewer, and
      // pushing a screen that then fails is worse than saying so.
      case DeepLinkKind.picture:
      case DeepLinkKind.event:
      case DeepLinkKind.request:
      case DeepLinkKind.campaign:
      case DeepLinkKind.chat:
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
          // Two different screens behind one link, because two different
          // people follow it. "You have a new invitation" goes to whoever
          // posted the request; "your invitation was accepted" and every
          // payment notice after it go to the photographer. They need opposite
          // things — one decides and pays, the other quotes and waits — so the
          // link resolves to whichever side the viewer is actually on.
          //
          // The server answers that, via `viewerRole` on the booking state:
          // it reads the caller's token, which is the only thing that can be
          // trusted about who is asking. A photographer who is not the chosen
          // one gets no booking state at all and lands on the requester
          // screen, which shows them the request and nothing private.
          final viewer = await AdsRepository().getBookingState(request.id);
          if (!mounted) return;

          // Replaces itself so Back returns to where the link was tapped
          // rather than to a spinner that has nothing left to do.
          _swapSelfFor(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'deeplink/request'),
              builder: (_) => viewer != null && !viewer.isRequester
                  ? PhotographerBookingPage(request: request)
                  : ReviewPhotographersPage(request: request),
            ),
          );
          return;

        // The details screen takes the campaign, not an id — it draws its
        // header, status pill and countdown from it before its own refetch
        // lands — so the campaign is fetched here. A campaign that was deleted,
        // or belongs to someone else, says so rather than opening an empty
        // screen.
        case DeepLinkKind.campaign:
          final campaign = await AdsRepository().getCampaign(link.id!);
          if (!mounted) return;
          _swapSelfFor(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'deeplink/campaign'),
              builder: (_) => CampaignDetailsPage(campaign: campaign),
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
        // to keep in step. The id is resolved to its event, the album opens,
        // and the album itself opens the photo once it has loaded the page
        // holding it.
        //
        // The album does that rather than this pushing a viewer directly,
        // because the viewer needs the *whole* list to be any use: a shared
        // photo should swipe on to the next one exactly like a tapped photo
        // does. Pushing a viewer from here could only hand it a single-item
        // list — the one photo we fetched — which looked right and then dead-
        // ended on the first swipe.
        case DeepLinkKind.picture:
          final photo = await sl<SearchUseCase>().picture(link.id!);
          if (!mounted) return;

          if (photo.eventId.isEmpty) {
            // Nothing to open it inside; show the one photo on its own.
            debugPrint('$_tag photo ${link.id} has no event — opening alone');
            _swapSelfFor(
              NoSwipeBackPageRoute<void>(
                settings: const RouteSettings(name: 'deeplink/photo'),
                builder: (_) => FoundPhotoViewerPage(photos: [photo]),
              ),
            );
            return;
          }

          debugPrint('$_tag opening album ${photo.eventId} at photo ${link.id}');
          _swapSelfFor(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'deeplink/album'),
              builder: (_) => SearchEventPhotosPage(
                eventId: photo.eventId,
                openPictureId: link.id,
              ),
            ),
          );
          return;

        // The room page takes a ChatRoom, not an id — it needs the member
        // list and the title to render its header at all — so the room is
        // fetched before the page is pushed.
        case DeepLinkKind.chat:
          final room = await sl<GetRoomUseCase>()(link.id!);
          if (!mounted) return;
          _swapSelfFor(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'deeplink/chat'),
              builder: (_) => ChatRoomPage(room: room),
            ),
          );
          return;

        case DeepLinkKind.myPhotos:
        case DeepLinkKind.photographer:
        case DeepLinkKind.home:
        case DeepLinkKind.notifications:
        case DeepLinkKind.adsDashboard:
        case DeepLinkKind.requestBoard:
        case DeepLinkKind.earnings:
        case DeepLinkKind.cart:
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
    // Untitled on purpose. This is on screen for a fraction of a second on its
    // way to the album, so a heading and a label just flash past — they read as
    // a stray screen rather than as progress. They earned their place only when
    // this route could be stranded here permanently, which it no longer can.
    //
    // The app bar stays for its back chevron, so a slow fetch can be backed out
    // of. The error text stays too: that one is a real message someone needs to
    // read, not a transient one.
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error ?? '', textAlign: TextAlign.center),
              ),
      ),
    );
  }
}
