import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:jperg_app/app.dart';
import 'package:jperg_app/core/app_readiness.dart';
import 'package:jperg_app/core/di/service_locator.dart';
// Temporarily disabled for presentation screenshots — re-enable with the call below.
// import 'package:jperg_app/core/security/screenshot_guard.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter Web ships with the semantic tree disabled until a screen reader is
  // detected. Force-enabling it (ensureSemantics) makes our Semantics labels
  // reach the DOM for role/label-based e2e tests — BUT it also switches web to
  // the semantics-based text-input path, which stops the left sidebar search
  // field (hosted in a bare Overlay above the Navigator) from receiving typed
  // characters: it focuses and shows a caret but no input arrives.
  //
  // So we only force it on when explicitly requested via the URL (?a11y=1).
  // Normal users get on-demand semantics and fully working text input; e2e
  // runs append ?a11y=1 to opt into the always-on accessibility tree.
  if (kIsWeb) {
    final params = Uri.base.queryParameters;
    if (params['a11y'] == '1' || params['semantics'] == '1') {
      SemanticsBinding.instance.ensureSemantics();
    }
  }

  // Cap Flutter's decoded-image cache to prevent OOM crashes on photo feeds.
  // The default (1000 images / unbounded bytes) is dangerously high for an app
  // that renders full-res photos — each decoded image can be 10–30 MB.
  // 50 images × ~2 MB avg decoded ≈ 100 MB; well under iOS's 2 GB hard limit.
  if (!kIsWeb) {
    PaintingBinding.instance.imageCache.maximumSize = 50;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  }

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

  // Prints once per launch. Its absence means the running binary predates the
  // deep-link session fixes, and any report from it is about the old code —
  // which cost several rounds of diagnosing a device that was not running what
  // was being diagnosed.
  debugPrint('[Startup] build marker: deeplink-session-fixes-v1');

  final authService = sl<AuthService>();

  // On iOS, Keychain entries survive app deletion — without this, a genuine
  // fresh install would silently inherit the previous install's token /
  // onboarding-seen flag and look like a returning user. Must complete
  // before the reads below, which would otherwise race the wipe.
  //
  // A fresh install no longer destroys the session, in any build.
  //
  // The marker lives in SharedPreferences, which is empty for any app the OS
  // considers new. That is true of a genuine first install — and equally of
  // every reinstall and every change of applicationId/bundle id. Deleting the
  // token here therefore signed people out for reasons that had nothing to do
  // with their session: reinstalling is the only way to make iOS re-fetch the
  // AASA, Android App Links need a Play-signed build installed fresh, and this
  // app's package has been renamed. Every one of those looked exactly like
  // "the deep link logged me out", because the launch that followed the
  // install was the one with the link in it.
  //
  // The property that mattered — a new install must not be able to *use* an
  // inherited session — is now enforced where it actually holds: the server.
  // A token it will not accept comes back 401, and AppInterceptors signs the
  // user out then, having checked the token's own `exp` claim. A token the
  // server still accepts was never a security problem to keep.
  if (await authService.isFreshInstall()) {
    await authService.markInstalled();
    debugPrint('[Startup] first launch for this install — session preserved; '
        'the server decides whether the token is still good');
  }

  // ── Run all independent startup checks in parallel ──────────────────────────
  // Previously these were 4 serial awaits (jailbreak check, two Keychain reads
  // for the token, one more for the expiration, and camera enumeration). Now
  // they all race together so the critical path is only as long as the slowest
  // one rather than the sum of all four.
  final results = await Future.wait([
    // [0] Jailbreak / root detection (skip on web — plugin not supported)
    if (kIsWeb)
      Future<bool>.value(false)
    else
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
  ]);

  final isDeviceCompromised = results[0] as bool;
  final token              = results[1] as String;
  final expiration         = results[2] as String;
  final hasSeenOnboarding  = results[3] as bool;
  final hasFaces           = results[4] as bool;

  // Whether the stored expiry has passed. Logged only — deliberately NOT used
  // to decide anything.
  //
  // The API layer stopped trusting this date on purpose (see
  // AppInterceptors.onRequest: "Always send the token — let the server decide
  // if it has expired"), because it marks perfectly good sessions dead. Routing
  // still trusted it, and the two disagreeing is what made a signed-in person
  // land on the guest feed: the token was blanked here, `nextRoute` in app.dart
  // read that blank and chose Discovery, while _AuthGuard — which reads the
  // real token — would have let them into Home. Nothing was ever logged out,
  // which is why relaunching appeared to "fix" it.
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

  // Seed the synchronous auth state before the first frame so the web
  // sidebar immediately renders the correct nav without an async round-trip.
  // Presence of a token, matching _AuthGuard and the interceptor.
  AuthService.isAuthenticated.value = token.isNotEmpty;
  AuthService.hasAddedFaces.value = hasFaces;
  // Role decides which tools the app offers, so a returning creator must not
  // spend the first frames looking like a viewer. Awaited rather than left to
  // settle: it is one keychain read, and the alternative is the creator
  // affordances flickering in a moment after the feed has drawn.
  await authService.primeRole();

  // Push. Off the critical path — none of this blocks the first frame.
  //
  // A session restored from the Keychain never runs the login flow, so without
  // the re-registration below a returning user would only be reachable by push
  // again after an explicit sign-in. OneSignal.login is idempotent, so calling
  // it on every launch costs nothing.
  if (!kIsWeb) {
    unawaited(() async {
      await PushNotificationService.instance.init();
      if (AuthService.isAuthenticated.value) {
        final userId = await authService.getUserId();
        await PushNotificationService.instance.login(userId);
        // Only where there is still a question to ask. It used to call
        // requestPermission outright on the belief that a recorded decision
        // makes it a no-op — it does not: with fallbackToSettings it opens the
        // system settings page, so anyone who had declined was sent there ten
        // seconds after opening the app, every single time.
        await Future.delayed(PushNotificationService.permissionPromptDelay);
        await PushNotificationService.instance.promptIfUndecided();
      }
    }());
  }

  // Web has no splash — it starts on Discovery — so nothing else will ever
  // report readiness there. Marked here so anything waiting on it is not
  // waiting forever.
  if (kIsWeb) AppReadiness.markReady();

  runApp(MyApp(
    // The real token, not a blanked one. This picks the first screen, and
    // blanking it here sent signed-in people to the guest feed.
    token: token,
    isDeviceCompromised: isDeviceCompromised,
    hasSeenOnboarding: hasSeenOnboarding,
  ));
}
