import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jperg_app/core/app_readiness.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/cloudinary_transform.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/features/discovery/data/services/feed_cache_service.dart';
import 'package:jperg_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:jperg_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The asset's own colour, sampled from the file.
///
/// Black, and that is the whole point of the change: the animation is drawn on
/// black and so is every screen behind it. It used to be the cream field of
/// the light cut, which put a full-screen flash from near-white to black at
/// the exact moment the app opened — the brand moment ending in a blink.
///
/// Matched exactly (#000000) rather than to a theme token: any difference at
/// all shows as a seam around a full-bleed asset.
const _kSplashBg = Color(0xFF000000);

/// The green the wordmark is drawn in, sampled from the same file, so anything
/// this screen adds belongs to the picture rather than to the theme.
const _kBrandGreen = Color(0xFF16795B);

/// Branded splash — plays `assets/splash/Splash_reducedg.gif` full-bleed, then
/// hands off to [nextRoute]. Shown on every cold start (mobile only).
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

  /// Passed as the route arguments of the one navigation this page makes, and
  /// read by the app's route table to build a [SplashHandoffRoute] instead of
  /// an ordinary push — so the app dissolves up over the brand screen rather
  /// than sliding in from the edge like a pushed detail page.
  ///
  /// Carried on the settings rather than decided by the route table on its own,
  /// because "/home" is also reached by the tab bar, by deep links and by
  /// sign-in, and those are ordinary pushes that should look like every other
  /// push in the app. What earns the dissolve is where the navigation came
  /// from, and this is the only way the destination gets told.
  static const handoff = Object();

  const SplashPage({super.key, required this.nextRoute});

  /// Route to replace this page with once the splash beat is done.
  final String nextRoute;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// Floor: the length of the animation itself — 108 frames summing to 3600 ms,
  /// added up from the file's own frame delays.
  ///
  /// It was 1200 ms, which is 40 frames in. The artwork *writes the wordmark
  /// on*, so at that point the mark is half-drawn, the dot is missing and the
  /// word "jperg" has not started — and that frozen half-logo is what the app
  /// cut away from on every warm start. A brand animation that never reaches
  /// its own last frame is worse than no animation.
  ///
  /// Then it was 3240 ms, which is 108 × 30 ms — the frame count times the
  /// delay on *most* of the frames. The file does not use one delay throughout:
  /// it mixes 30 ms and 40 ms, and the real total is 3600. So the floor was
  /// still landing ten frames early, on the same kind of not-quite-finished
  /// mark, just far less obviously.
  ///
  /// This is a floor, not a wait: the feed warm-up below runs alongside it, so
  /// on a cold start the fetch is happening during the animation rather than
  /// after it. What it costs is the difference between the two, and only when
  /// the network is faster than the artwork.
  static const _kMinDisplay = Duration(milliseconds: 3600);

  /// Ceiling on waiting for content. Long enough for a slow first fetch, short
  /// enough that a request which is never coming back doesn't trap the user.
  static const _kMaxWait = Duration(seconds: 6);

  /// Ceiling on waiting for the top card's *photo*, separately and much sooner.
  ///
  /// Deliberately shorter than [_kMinDisplay], which is what makes it free: on
  /// a warm cache the animation is still playing throughout, so a picture that
  /// arrives costs nothing and a picture that never does costs nothing either.
  /// Sharing [_kMaxWait] instead held a returning user with no signal on the
  /// splash for six seconds to warm an image that was never coming — trading
  /// the spinner this was meant to remove for a longer wait before it.
  ///
  /// The card behind this works without it. A photo still loading shows its
  /// backdrop and a spinner, which is the state every other card in the feed
  /// passes through; this is only about the first one, which is the only one
  /// nobody chose to look at.
  static const _kMediaWarmBudget = Duration(seconds: 3);

  /// One page of events — the same page `DiscoveryBloc` asks for, because the
  /// bloc now adopts this page rather than fetching its own. It had drifted:
  /// the comment here claimed the two matched while this asked for ten and the
  /// bloc asked for twenty, which was harmless only for as long as the page
  /// was going to be thrown away and refetched.
  static const _kPageSize = 20;

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
    Navigator.of(context)
        .pushReplacementNamed(widget.nextRoute, arguments: SplashPage.handoff);
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
    _dropLinkListener =
        () => DeepLinkService.isWaiting.removeListener(listener);
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
  ///
  /// Two halves, and the second is the one that shows. Feed *data* on its own
  /// buys a card with a blurred backdrop and a spinner on it, because the photo
  /// the card is made of is a separate download that had not started yet — so
  /// the brand animation handed over to a dark screen with a ring spinning on
  /// it, which is exactly the moment this page exists to remove. Being ready
  /// means the first picture has been decoded, not that its JSON has arrived.
  Future<void> _warmFirstScreen() async {
    // The onboarding carousel is local; there is no feed behind it to wait for.
    if (widget.nextRoute == OnboardingPage.routeName) return;

    final cache = sl<FeedCacheService>();
    var events = cache.restore();

    if (events.isEmpty) {
      try {
        events = await sl<GetRandomImagesUseCase>()(
          take: _kPageSize,
          skip: 0,
          userId: await sl<AuthService>().getUserId(),
        );
        // Marked as this launch's own page, so the bloc adopts it instead of
        // asking for the first page a second time. Every `skip == 0` is a
        // fresh deal server-side, so a second request would hand back a
        // different top card — and take away the one this page just spent the
        // brand animation decoding. See [FeedCacheService.takeHandoff].
        if (events.isNotEmpty) {
          await cache.save(events, warmedForLaunch: true);
        }
      } catch (e) {
        debugPrint('[Splash] feed warm-up failed, going on anyway: $e');
        return;
      }
    }

    await _warmFirstCardMedia(events).timeout(_kMediaWarmBudget, onTimeout: () {
      debugPrint('[Splash] first picture is slow, going on without it');
    });
  }

  /// Decodes the top card's picture while the animation is still playing.
  ///
  /// Only the first card, deliberately. It is the one the person lands on, the
  /// rest are a swipe away and load in the time that swipe takes, and every
  /// extra photo warmed here is one more thing the splash is waiting for.
  ///
  /// Both layers of it, because the card draws both: the blurred backdrop
  /// behind the photo is its own 80 px fetch, and leaving that one cold shows
  /// the empty fill around a photo that is otherwise ready. They are warmed
  /// together — the backdrop is a few KB and shares the connection.
  ///
  /// A video at the top warms only the backdrop, which for a clip is its poster
  /// frame: the player is a different subsystem with its own first frame, and
  /// nothing here can hurry it.
  Future<void> _warmFirstCardMedia(List<EventDiscovery> events) async {
    if (events.isEmpty) return;
    final pictures = events.first.pictures;
    if (pictures.isEmpty) return;

    // The frame this page is being built in has to finish first.
    //
    // A warm cache is the path with no `await` in front of it: `restore()` is
    // synchronous, so everything above runs inside `initState`, and reading
    // MediaQuery there throws `dependOnInheritedWidgetOfExactType called before
    // initState completed`. That threw away the warm-up on exactly the start it
    // was written for — a returning user, cache full, one decode short of a
    // first frame with a photo on it.
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;

    final url = pictures.first.url;
    // Full-bleed: the card is as wide as the window, which is what decides both
    // the Cloudinary width and the decode width. Read off MediaQuery rather
    // than screenutil's `.w`, which is not initialised on this route yet.
    final width = MediaQuery.sizeOf(context).width;

    await Future.wait([
      JpergImage.precache(context, url,
          logicalWidth: width, isBlurBackground: true),
      if (!CloudinaryTransform.isVideoUrl(url))
        JpergImage.precache(context, url, logicalWidth: width),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSplashBg,
      // Opaque until the moment it is replaced, deliberately.
      //
      // Fading the wordmark out before navigating leaves the scaffold's own
      // black on screen with nothing on it — a blank black screen between the
      // brand moment and the app, which is the seam this whole change is
      // about. The destination transitions in *over* a splash that is still
      // fully painted, so there is never a frame showing neither.
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              // The dark cut, with the wordmark drawn smaller. Same 108 frames
              // over the same 3.6 s as `Splash_small`, so the timing above is
              // unchanged — what differs is the type size and a quarter of the
              // bytes to decode on the one screen where nothing else is
              // competing for the frame budget.
              //
              // The file plays **once** and holds its last frame, and it has to
              // stay that way. As exported it carried a GIF loop extension set
              // to infinite, which Flutter honours: a start slower than 3.6 s —
              // exactly the start this screen exists for — wiped the finished
              // wordmark and drew it on again, on a loop, while the person
              // waited. The still mark plus [_StillWorking] is the waiting
              // state; a re-running brand animation is a screen that looks like
              // it has restarted. A re-export will bring the loop back: strip
              // the NETSCAPE2.0 application extension from the gif again.
              'assets/splash/Splash_reducedg.gif',
              fit: BoxFit.cover,
            ),

            // Only once the animation has finished having its say.
            //
            // Instagram holds its mark and, if the app is still fetching,
            // shows something small underneath rather than replacing the
            // brand screen with a spinner. Before the last frame there is
            // nothing to report — the animation *is* the loading state for
            // those three seconds, and a second thing moving over it would be
            // two things asking for attention at once.
            //
            // On a warm start this page is usually gone before it appears at
            // all, which is the intended common case.
            Positioned(
              left: 0,
              right: 0,
              // Logical pixels, not `.h`.
              //
              // This page is shown before [ScreenUtilInit] has initialised —
              // the splash is the app's first route — and screenutil's
              // extensions throw a LateInitializationError until it has. The
              // artwork behind this is `BoxFit.cover` on a fixed 400x740
              // anyway, so scaling the dots to the device would drift them off
              // a mark that does not scale with it.
              bottom: 88,
              child: _StillWorking(after: _kMinDisplay),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots under the wordmark, once the animation has ended and the app is
/// still waiting.
///
/// Deliberately not a spinner. A spinner on a brand screen reads as a stall;
/// a slow pulse travelling along three dots reads as the app still working,
/// which is the same fact told in the register the rest of this screen is in.
class _StillWorking extends StatefulWidget {
  const _StillWorking({required this.after});

  /// How long to stay out of the way — the length of the animation.
  final Duration after;

  @override
  State<_StillWorking> createState() => _StillWorkingState();
}

class _StillWorkingState extends State<_StillWorking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  Timer? _reveal;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _reveal = Timer(widget.after, () {
      if (!mounted) return;
      setState(() => _shown = true);
      _pulse.repeat();
    });
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Where this dot sits in the travelling pulse.
  ///
  /// Floored well above zero: a dot that goes out entirely reads as a gap in
  /// the row rather than as one dot resting.
  double _opacityOf(int index) {
    final phase = (_pulse.value - index * 0.18) % 1.0;
    return 0.3 + ((math.sin(phase * 2 * math.pi) + 1) / 2) * 0.7;
  }

  @override
  Widget build(BuildContext context) {
    // Held in the tree at zero rather than absent, so its arrival is a fade
    // and not a relayout of the stack it sits in.
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 7,
          child: !_shown
              ? null
              : AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) SizedBox(width: 7),
                        Opacity(
                          opacity: _opacityOf(i),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _kBrandGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
