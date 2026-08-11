import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jperg_app/core/app_readiness.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/discovery/data/services/feed_cache_service.dart';
import 'package:jperg_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:jperg_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The asset's own colour. The gif is a near-white field, so a dark scaffold
/// behind it showed as a black flash for the frame or two before it decoded.
const _kSplashBg = Color(0xFFF7F7F2);

/// Branded splash — plays `assets/splash/splash.gif` full-bleed, then hands off
/// to [nextRoute]. Shown on every cold start (mobile only).
///
/// It holds until the screen behind it can actually show something, rather than
/// for a fixed beat. Both destinations that matter open on the feed, and
/// [DiscoveryBloc] paints instantly *if* [FeedCacheService] has something to
/// restore — that read is synchronous. With a cold cache it emits a loading
/// state and waits on the network instead, which is what used to leak through:
/// the splash left after 1.8 s regardless, so a slow first launch went from
/// brand animation to an empty screen.
///
/// So the wait is bounded on both sides. [_kMinDisplay] stops the gif being a
/// flicker on a warm start, and [_kMaxWait] stops a dead network stranding
/// anyone here — past it the app goes on and the feed shows its own loading
/// state, which is the honest thing to do at that point.
///
/// A deep link waiting to open cancels the wait outright. Both bounds are
/// about the *feed* being worth looking at, and someone who tapped a link is
/// on their way somewhere else.
class SplashPage extends StatefulWidget {
  static const routeName = '/splash';

  const SplashPage({super.key, required this.nextRoute});

  /// Route to replace this page with once the splash beat is done.
  final String nextRoute;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// Floor: below about this the animation reads as a glitch rather than a
  /// brand moment.
  static const _kMinDisplay = Duration(milliseconds: 1200);

  /// Ceiling on waiting for content. Long enough for a slow first fetch, short
  /// enough that a request which is never coming back doesn't trap the user.
  static const _kMaxWait = Duration(seconds: 6);

  /// One page of events — matches `DiscoveryBloc`'s own first request, so the
  /// cache this leaves behind is the size that bloc expects to restore.
  static const _kPageSize = 10;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    // Whichever comes first: the beat below, or a deep link turning up.
    //
    // A held link waits for this page to finish before it can open anything —
    // that ordering is deliberate, because the pushReplacement below would
    // otherwise throw the link's screen away. But "wait for the splash to
    // navigate" had become "wait for the splash to warm a feed the person is
    // not going to look at", and a link tapped in an email or a notification
    // sat behind 1.2s of brand beat plus a fetch of up to six seconds before
    // anything started happening.
    //
    // So the ordering is kept and the waiting is not: as soon as a link is
    // parked, hand over. The feed warm-up carries on in the background and
    // still populates the cache for whatever is underneath.
    await Future.any([_beat(), _aLinkIsWaiting()]);
    // A link parked before this page mounted resolves the race in a microtask,
    // and microtasks drain inside the frame that is still building this
    // splash — so the pushReplacement below would land mid-build and throw
    // `markNeedsBuild() called during build` on the Overlay, leaving the
    // navigator locked for the session. Waiting for the end of the frame costs
    // nothing on the timed path, where the frame is long over.
    await SchedulerBinding.instance.endOfFrame;
    // Gone already — something else has navigated, so the stack is real and
    // whatever is waiting on readiness should stop waiting. Marked here too, or
    // a link held since launch would never be followed at all.
    if (!mounted) {
      AppReadiness.markReady();
      return;
    }
    // The single line that says whether the app considered you signed in. Read
    // it with `[Startup] … token=` above: token=true landing on anything other
    // than /home means the routing disagreed with the session, which is the
    // bug this pairing exists to make obvious rather than guess at.
    debugPrint('[Splash] → ${widget.nextRoute}');
    Navigator.of(context).pushReplacementNamed(widget.nextRoute);
    // Only now is it safe for a deep link to push: this replaced the top of the
    // stack, so anything opened before this point would have been thrown away.
    // A link held since launch is followed from here.
    AppReadiness.markReady();
  }

  /// The brand beat and the warm-up, as one future that never throws.
  ///
  /// Swallowing is the point: this is raced against [_aLinkIsWaiting], and a
  /// future that loses a [Future.any] still delivers its error — to nobody,
  /// which Dart reports as an unhandled async exception.
  Future<void> _beat() async {
    try {
      await Future.wait([
        Future<void>.delayed(_kMinDisplay),
        _warmFirstScreen().timeout(_kMaxWait, onTimeout: () {}),
      ]);
    } catch (e) {
      debugPrint('[Splash] warm-up failed, going on anyway: $e');
    }
  }

  /// Completes as soon as a deep link is parked — immediately if one already
  /// is, which is the usual case for a link that launched the app.
  ///
  /// The listener removes itself, so losing the race above costs nothing.
  Future<void> _aLinkIsWaiting() {
    if (DeepLinkService.isWaiting.value) return Future<void>.value();
    final completer = Completer<void>();
    late final VoidCallback listener;
    listener = () {
      if (!DeepLinkService.isWaiting.value) return;
      DeepLinkService.isWaiting.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    };
    DeepLinkService.isWaiting.addListener(listener);
    _dropLinkListener = () => DeepLinkService.isWaiting.removeListener(listener);
    return completer.future;
  }

  /// Detaches the listener above when this page goes, so a splash that was
  /// disposed mid-wait does not leave one behind on a static notifier.
  VoidCallback? _dropLinkListener;

  @override
  void dispose() {
    _dropLinkListener?.call();
    super.dispose();
  }

  /// Gets the destination to the point where it has something to draw.
  ///
  /// Nothing here talks to [DiscoveryBloc] — it is registered as a factory, so
  /// the instance this page could build is not the one the destination will
  /// use. It works through the cache instead, which both share: fetch the first
  /// page, persist it, and the bloc's synchronous `restore()` hits on its very
  /// first frame. That also means a failure here costs nothing — the bloc still
  /// makes its own request, and the user sees its loading state exactly as they
  /// would have.
  Future<void> _warmFirstScreen() async {
    // The onboarding carousel is local; there is no feed behind it to wait for.
    if (widget.nextRoute == OnboardingPage.routeName) return;

    final cache = sl<FeedCacheService>();
    if (cache.restore().isNotEmpty) return;

    try {
      final events = await sl<GetRandomImagesUseCase>()(
        take: _kPageSize,
        skip: 0,
        userId: await sl<AuthService>().getUserId(),
      );
      if (events.isNotEmpty) await cache.save(events);
    } catch (e) {
      debugPrint('[Splash] feed warm-up failed, going on anyway: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSplashBg,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash/splash.gif',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
