import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:jperg_app/app.dart';
import 'package:jperg_app/core/cache/platform_http_client.dart';
import 'package:jperg_app/core/di/service_locator.dart';
// Temporarily disabled for presentation screenshots — re-enable with the call below.
// import 'package:jperg_app/core/security/screenshot_guard.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/premium_invite_prompt.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_watcher.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/purchase/ios_store.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/feedback/feedback_prompt.dart';
import 'package:jperg_app/services/push_notification_service.dart';
import 'package:jperg_app/features/settings/presentation/personalisation_prompt.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap Flutter's decoded-image cache to prevent OOM crashes on photo feeds.
  // The default (1000 images / unbounded bytes) is dangerously high for an app
  // that renders full-res photos — each decoded image can be 10–30 MB.
  //
  // The byte ceiling is the real guard and has not moved: 100 MB, well under
  // iOS's limit. The *count* is up from 50 because the ladder made entries
  // much smaller — a grid thumbnail decodes to a few hundred kilobytes, not
  // megabytes — so 50 slots started evicting photos the reader could still
  // see while the budget sat half unused. Whichever limit binds first still
  // wins, so a feed of full-width frames is capped by bytes exactly as before.
  PaintingBinding.instance.imageCache.maximumSize = 120;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Block screenshots / screen recording app-wide before the first frame.
  // TEMPORARILY DISABLED for presentation screenshots — re-enable before release.
  // await enableScreenshotProtection();

  final sw = Stopwatch()..start();

  await setupServiceLocator();
  debugPrint('[Startup] DI ready — ${sw.elapsedMilliseconds}ms');

  // Fire-and-forget — never blocks startup; failures use safe defaults.
  Future.wait([
    sl<AppConfigRepository>().fetch(),
    sl<AppConfigRepository>().fetchRates(),
  ]).ignore();

  // And again on every return to the foreground, so a flag thrown on the admin
  // dashboard reaches an app that is already running. See AppConfigWatcher.
  AppConfigWatcher(sl<AppConfigRepository>().fetch).start();

  // Listen for App Store transactions from launch, not from the screen that
  // started one. StoreKit replays a purchase that was never finished —
  // somebody paid for a boost, the app was killed before the server applied
  // it, and the transaction comes back on the *next* launch. With nothing
  // listening then, that buyer has paid for a boost they never got.
  //
  // The order token Apple carries on the transaction is all the server needs:
  // its pending payment row knows which request the boost was for.
  //
  // iOS only, and a no-op elsewhere — a boost is the one thing sold through
  // In-App Purchase. Photographs and bookings go through Paystack.
  if (IosStore.instance.isSupported) {
    IosStore.instance.start(resolver: (details) async {
      final token = OrderToken.of(details);
      if (token == null) {
        // Nothing ties this to an order. Finishing it is the only option that
        // does not replay forever.
        await IosStore.instance.finish(details);
        return;
      }
      try {
        final applied = await sl<AdsRepository>().settleIosBoost(
          orderToken: token,
          signedTransaction: details.verificationData.serverVerificationData,
        );
        if (applied) await IosStore.instance.finish(details);
      } catch (e) {
        // Left unfinished on purpose: StoreKit offers it again next launch,
        // which is the behaviour that eventually delivers the boost.
        debugPrint('[IAP] could not settle a replayed boost: $e');
      }
    }).ignore();
  }

  // Prints once per launch. Its absence means the running binary predates the
  // deep-link session fixes, and any report from it is about the old code —
  // which cost several rounds of diagnosing a device that was not running what
  // was being diagnosed.
  debugPrint('[Startup] build marker: deeplink-session-fixes-v1');

  // Which HTTP stack photos are being fetched over — and the only way to find
  // out, since QUIC negotiation cannot be exercised in a test.
  //
  // 'cupertino' or 'cronet' means HTTP/3 is available; 'dart:io' means the
  // platform stack could not be built — expected on an Android device without
  // Google Play Services — and every image is on HTTP/1.1, which stalls the
  // whole connection on one dropped packet. See [PlatformHttpClient].
  debugPrint('[Startup] image transport: ${PlatformHttpClient.kind}');

  final authService = sl<AuthService>();

  // A new install starts over. Nothing is inherited.
  //
  // On iOS the Keychain outlives the app: delete Jperg, install it again, and
  // the previous install's token, role, avatar and onboarding-seen flag are
  // all still sitting there. So the "fresh" install came up as whoever used
  // the phone last, and skipped a carousel the new owner had never seen.
  // Android wipes its own sandbox and sets allowBackup="false", so the
  // symptom was iOS-only — but the rule below is the same on both, because
  // the rule is about what a new install *means*, not about which store
  // happens to leak.
  //
  // This is how the big apps behave: reinstalling signs you out and puts you
  // back at the intro. An earlier version preserved the session instead and
  // let the server reject the token, because an empty SharedPreferences also
  // describes reinstalls done for other reasons — re-fetching the AASA,
  // getting a Play-signed build for App Links, the package rename — and
  // signing out on those read as "the deep link logged me out". That is the
  // accepted cost of this decision: a reinstall now means signing in again.
  // Deliberately, and in exchange for the thing that matters more — a phone
  // wiped to be rid of an account does not come back wearing it.
  //
  // Must finish before the reads below, which would otherwise race the wipe
  // and seed the first frame from keys that are about to vanish. Guarded
  // because a Keychain that throws here is not worth a black screen in front
  // of `runApp`, and [firstRouteFor] is told about the install directly — so
  // the carousel still comes up first even on a launch where nothing could be
  // deleted.
  final isFreshInstall = await authService.isFreshInstall();
  if (isFreshInstall) {
    try {
      await authService.resetAllForFreshInstall();
    } catch (e) {
      debugPrint('[Startup] fresh install: could not clear stored state: $e');
    }
    await authService.markInstalled();
    debugPrint('[Startup] first launch for this install — starting over');
  }

  // ── Run all independent startup checks in parallel ──────────────────────────
  // Previously these were 4 serial awaits (jailbreak check, two Keychain reads
  // for the token, one more for the expiration, and camera enumeration). Now
  // they all race together so the critical path is only as long as the slowest
  // one rather than the sum of all four.
  //
  // Everything the first frame needs is in here, including the two `prime`
  // calls at the end, which used to be awaited one after the other *after*
  // this completed — two more serial Keychain round trips in front of
  // `runApp`, on the stretch where the screen is still the OS launch image.
  // They read different keys and depend on nothing here, so they belong in the
  // same batch.
  // Started here and awaited below, so they overlap the batch without taking
  // a position in it.
  //
  // They were in the list, read as `results[7]` and `results[8]`. Two
  // positions were then inserted above them by other work, so `results[8]`
  // became a `Future<void>`'s null and `null as bool` threw — in `main`,
  // before `runApp`, which is a black screen and no second chance. A list of
  // Object? indexed by hand is a shared mutable counter disguised as code, and
  // nothing about it fails until it fails completely.
  //
  // [OnboardingStep]: how far into the signup wizard this account got. A token
  // means the account exists; it does not mean the wizard finished.
  final onboardingStepFuture = authService.getOnboardingStep();
  // Whether they chose to look around without an account — its own answer,
  // because `hasSeenOnboarding` means only that the carousel played.
  final isGuestFuture = authService.getIsGuest();

  final results = await Future.wait<Object?>([
    // [0] Jailbreak / root detection (skip on web — plugin not supported)
    Future<bool>(() async {
      try {
        return await FlutterJailbreakDetection.jailbroken;
      } catch (_) {
        return false; // simulator or plugin unavailable — treat as safe
      }
    }),
    // [1] Auth token (one Keychain read)
    authService.getToken(),
    // [2] Token expiration string (one Keychain read — avoids isTokenExpired()
    //     re-reading the token a second time internally)
    authService.getExpiration(),
    // [3] Whether the first-run onboarding carousel has already been shown.
    authService.getHasSeenOnboarding(),
    // [4] Whether a reference selfie is on file — gates the Found tab. Seeded
    //     here so the gate resolves on the first frame instead of flashing.
    authService.getHasAddedFaces(),
    // [5] Role decides which tools the app offers, so a returning creator must
    //     not spend the first frames looking like a viewer. Seeds
    //     AuthService.role rather than returning anything.
    authService.primeRole(),
    // [6] Same, for the avatar: without it the first frame draws initials for
    //     an account whose picture is already on disk.
    authService.primeProfileUrl(),
    //     And the name behind those initials, for an account with no picture
    //     — otherwise the avatar opens on '?' and corrects itself a moment
    //     later; and who they are, so a profile screen can tell on its first
    //     frame whether it is looking at its own account.
    authService.primeName(),
    authService.primeUserId(),
  ]);

  final isDeviceCompromised = results[0] as bool;
  final token = results[1] as String;
  final expiration = results[2] as String;
  final hasSeenOnboarding = results[3] as bool;
  final hasFaces = results[4] as bool;
  final onboardingStep = await onboardingStepFuture;
  final isGuest = await isGuestFuture;

  // Whether the stored expiry has passed. Logged only — deliberately NOT used
  // to decide anything.
  //
  // The API layer stopped trusting this date on purpose (see
  // AppInterceptors.onRequest: "Always send the token — let the server decide
  // if it has expired"), because it marks perfectly good sessions dead. Routing
  // still trusted it, and the two disagreeing is what made a signed-in person
  // land on the guest feed: the token was blanked here, `nextRoute` in app.dart
  // read that blank and chose Discovery, while _AuthGuard — which went back to
  // the Keychain for the real token — would have let them into Home. Nothing
  // was ever logged out, which is why relaunching appeared to "fix" it. (Both
  // now read the same seeded flag, so they can no longer disagree at all.)
  //
  // Production issues 48-hour tokens (JWT_ACCESS_TOKEN_TIME defaults to 48 and
  // is not set on the server), so this fired for every user every two days.
  //
  // A token that really is dead now gets the server's answer instead of a
  // guess: the first request 401s and the interceptor signs them out properly.
  bool storedExpiryPassed = false;
  if (token.isNotEmpty && expiration.isNotEmpty) {
    try {
      storedExpiryPassed = DateTime.now().isAfter(DateTime.parse(expiration));
    } catch (_) {
      storedExpiryPassed = false;
    }
  }

  debugPrint('[Startup] all checks done — ${sw.elapsedMilliseconds}ms '
      '(token=${token.isNotEmpty} storedExpiryPassed=$storedExpiryPassed '
      'compromised=$isDeviceCompromised)');

  // Seed the synchronous auth state before the first frame, so the first
  // screen is chosen without an async round-trip. Presence of a token,
  // matching _AuthGuard and the interceptor.
  // Presence of a token, matching _AuthGuard and the interceptor — and read by
  // both guards in app.dart as *the* answer to "is this session real", with no
  // Keychain read of their own. So it has to be set before the first frame,
  // not merely before the first request.
  AuthService.isAuthenticated.value = token.isNotEmpty;
  AuthService.hasAddedFaces.value = hasFaces;

  // Push. Off the critical path — none of this blocks the first frame.
  //
  // A session restored from the Keychain never runs the login flow, so without
  // the re-registration below a returning user would only be reachable by push
  // again after an explicit sign-in. OneSignal.login is idempotent, so calling
  // it on every launch costs nothing.
  // How many times this device has opened the app, which is half of what
  // decides whether to ask for a rating — see [FeedbackPrompt]. Counted here
  // rather than in the shell so a launch that ends on the feed still counts,
  // and unawaited because nothing about starting up waits on a counter.
  unawaited(FeedbackPrompt.noteLaunch());
  unawaited(PersonalisationPrompt.noteLaunch());
  // The premium tier's invitation is paced the same way — see
  // [PremiumInvitePrompt], which owns every condition on when it appears.
  unawaited(PremiumInvitePrompt.noteLaunch());

  unawaited(() async {
    await PushNotificationService.instance.init();

    // No permission prompt here. It is asked for on Home — see
    // [PushNotificationService.promptOnHome], which is the only caller.
    //
    // Asking from here asked on every launch, signed in or not, which on a
    // fresh install put the system dialog over onboarding: no account, and no
    // idea yet what the notifications were for. The ask is spent when it is
    // put, so a "no" collected there cannot be asked again.
    //
    // `init` stays — registering with the SDK and reconciling the token below
    // raise no dialog and have to happen whether or not anybody is asked.

    // Everything a push needs, asserted together: attached to this account,
    // opted in unless the master switch says otherwise, and not left opted
    // out behind a permission granted since. Re-asserted on every launch
    // rather than only when the settings screen is opened, because the people
    // affected are precisely the ones who went there once and believe it is
    // dealt with.
    //
    // A signed-out launch is asserted too, and that is the half this used to
    // miss: it passed null and reconcile left the alias alone, so a device
    // still carrying the account that signed out last went on receiving their
    // notifications — the "I logged in with a different account and the old
    // one kept getting everything" report. adoptSession detaches instead.
    String? userId;
    if (AuthService.isAuthenticated.value) {
      // Guarded because it is a Keychain read on the startup path: a throw
      // here is not a reason to skip reconciling the rest.
      try {
        userId = await authService.getUserId();
      } catch (e) {
        debugPrint('[Startup] could not read the user id for push: $e');
      }
    }
    // "Signed in, but I could not find out as whom" is not the same as "signed
    // out", and only the second one may detach. A throw above leaves userId
    // null, and getUserId answers '' rather than null when the key is simply
    // missing — so both have to be read as unknown, or a Keychain that lost one
    // entry would unregister a device whose token is perfectly good.
    final known = userId != null && userId.isNotEmpty;
    if (!known && AuthService.isAuthenticated.value) {
      await PushNotificationService.instance.reconcile();
    } else {
      await PushNotificationService.instance.adoptSession(userId);
    }
  }());

  runApp(MyApp(
    // The real token, not a blanked one. This picks the first screen, and
    // blanking it here sent signed-in people to the guest feed.
    token: token,
    isDeviceCompromised: isDeviceCompromised,
    hasSeenOnboarding: hasSeenOnboarding,
    onboardingStep: onboardingStep,
    isGuest: isGuest,
    // Outranks all four of the above — see [firstRouteFor].
    isFreshInstall: isFreshInstall,
  ));
}
