import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:skidoo_app/app.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // must be after WidgetsFlutterBinding

  // Cap Flutter's decoded-image cache to prevent OOM crashes on photo feeds.
  // The default (1000 images / unbounded bytes) is dangerously high for an app
  // that renders full-res photos — each decoded image can be 10–30 MB.
  // 50 images × ~2 MB avg decoded ≈ 100 MB; well under iOS's 2 GB hard limit.
  if (!kIsWeb) {
    PaintingBinding.instance.imageCache.maximumSize = 50;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  }

  // On web, Flutter 3.22+ no longer generates AssetManifest.json (only the
  // binary AssetManifest.bin). google_fonts still checks for the JSON file
  // first — allow CDN fetching so it can fall back cleanly without errors.
  if (kIsWeb) GoogleFonts.config.allowRuntimeFetching = true;

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final sw = Stopwatch()..start();

  await setupServiceLocator();
  debugPrint('[Startup] DI ready — ${sw.elapsedMilliseconds}ms');

  // Fire-and-forget — never blocks startup; failures use safe defaults.
  Future.wait([
    sl<AppConfigRepository>().fetch(),
    sl<AppConfigRepository>().fetchRates(),
  ]).ignore();

  final authService = sl<AuthService>();

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
  ]);

  final isDeviceCompromised = results[0] as bool;
  final token              = results[1] as String;
  final expiration         = results[2] as String;

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

  runApp(MyApp(
    token: isExpired ? '' : token,
    isDeviceCompromised: isDeviceCompromised,
  ));
}
