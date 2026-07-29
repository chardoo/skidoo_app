import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:media_kit/media_kit.dart';
import 'package:skidoo_app/app.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
// Temporarily disabled for presentation screenshots — re-enable with the call below.
// import 'package:skidoo_app/core/security/screenshot_guard.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // must be after WidgetsFlutterBinding

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

  final authService = sl<AuthService>();

  // On iOS, Keychain entries survive app deletion — without this, a genuine
  // fresh install would silently inherit the previous install's token /
  // onboarding-seen flag and look like a returning user. Must complete
  // before the reads below, which would otherwise race the wipe.
  if (await authService.isFreshInstall()) {
    await authService.resetAllForFreshInstall();
    await authService.markInstalled();
    debugPrint('[Startup] fresh install detected — cleared stale Keychain data');
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

  // Replicate isTokenExpired() logic without a second Keychain round-trip.
  bool isExpired = token.isEmpty;
  if (!isExpired && expiration.isNotEmpty) {
    try {
      isExpired = DateTime.now().isAfter(DateTime.parse(expiration));
    } catch (_) {
      isExpired = false;
    }
  }

  debugPrint('[Startup] all checks done — ${sw.elapsedMilliseconds}ms '
      '(token=${token.isNotEmpty} expired=$isExpired compromised=$isDeviceCompromised)');

  // Seed the synchronous auth state before the first frame so the web
  // sidebar immediately renders the correct nav without an async round-trip.
  AuthService.isAuthenticated.value = !isExpired && token.isNotEmpty;
  AuthService.hasAddedFaces.value = hasFaces;

  runApp(MyApp(
    token: isExpired ? '' : token,
    isDeviceCompromised: isDeviceCompromised,
    hasSeenOnboarding: hasSeenOnboarding,
  ));
}
