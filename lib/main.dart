import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:skidoo_app/app.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await setupServiceLocator();

  // ── Device integrity check ──────────────────────────────────────────────────
  // On iOS this checks for Cydia, jailbreak artefacts, and writable system
  // paths.  On Android it checks for su binaries and test-keys builds.
  bool isDeviceCompromised = false;
  try {
    isDeviceCompromised = await FlutterJailbreakDetection.jailbroken;
  } catch (_) {
    // Plugin unavailable (e.g. simulator) — treat device as safe.
  }

  // ── Token validity check ────────────────────────────────────────────────────
  final authService = sl<AuthService>();
  final token = await authService.getToken();
  final isExpired = await authService.isTokenExpired();
  // An expired token is treated the same as having no token: user goes to
  // the discovery/login flow rather than straight to the home feed.
  final effectiveToken = isExpired ? '' : token;

  final cameras = await availableCameras();
  final firstCamera = cameras.isNotEmpty ? cameras.first : null;

  runApp(MyApp(
    token: effectiveToken,
    firstCamera: firstCamera,
    isDeviceCompromised: isDeviceCompromised,
  ));
}
