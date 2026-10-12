/// What the QR scanner shows when the camera has been refused.
///
/// It showed a working scanner. `MobileScanner`'s own error view is drawn
/// *inside* the widget, and this page lays a scan frame, a torch button and a
/// "point at the code" caption over it — so a refusal read as a camera that
/// had not started yet, with the explanation tucked underneath the frame and
/// nothing to tap. Short of finding the switch in iOS Settings unaided, there
/// was no way to change your mind.
///
/// It stands down now and offers the Settings button, exactly as the selfie
/// page does — see [CameraBlocked], which both screens share.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/camera_blocked.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        home: child,
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('when the camera was refused', () {
    testWidgets('there is a button to open Settings', (t) async {
      var opened = false;
      await t.pumpWidget(host(CameraBlocked(
        message: 'jperg needs your camera to scan a QR code.',
        onOpenSettings: () => opened = true,
        onBack: () {},
      )));

      expect(find.text('Open Settings'), findsOneWidget);

      await t.tap(find.text('Open Settings'));
      await t.pump();

      expect(opened, isTrue);
    });

    testWidgets('it says what the camera is for, in the reader\'s terms',
        (t) async {
      // Not `MobileScannerException.toString()`, which is an error code and a
      // raw platform message — and which is what the plugin's default view
      // put on screen.
      await t.pumpWidget(host(CameraBlocked(
        message: 'jperg needs your camera to scan a QR code.',
        onOpenSettings: () {},
        onBack: () {},
      )));

      expect(find.textContaining('scan a QR code'), findsOneWidget);
      expect(find.textContaining('MobileScannerException'), findsNothing);
      expect(find.textContaining('permissionDenied'), findsNothing);
    });

    testWidgets('and it says what to do after granting it', (t) async {
      await t.pumpWidget(host(CameraBlocked(
        message: 'jperg needs your camera to scan a QR code.',
        onOpenSettings: () {},
        onBack: () {},
      )));

      expect(find.textContaining('come back to this screen'), findsOneWidget);
    });

    testWidgets('there is always a way back out', (t) async {
      var backed = false;
      await t.pumpWidget(host(CameraBlocked(
        message: 'jperg needs your camera to scan a QR code.',
        onOpenSettings: () {},
        onBack: () => backed = true,
      )));

      await t.tap(find.bySemanticsLabel('Back'));
      await t.pump();

      expect(backed, isTrue);
    });
  });

  group('when Settings cannot fix it', () {
    testWidgets('no button is offered', (t) async {
      // An unsupported device, or a camera already in use. Sending somebody
      // to a switch that is already on is worse than saying nothing.
      await t.pumpWidget(host(const CameraBlocked(
        message: 'This device cannot scan QR codes.',
        onBack: _noop,
      )));

      expect(find.text('Open Settings'), findsNothing);
      expect(find.textContaining('cannot scan'), findsOneWidget);
    });

    testWidgets('but there is still a way back', (t) async {
      var backed = false;
      await t.pumpWidget(host(CameraBlocked(
        message: 'The camera could not be started.',
        onBack: () => backed = true,
      )));

      await t.tap(find.bySemanticsLabel('Back'));
      await t.pump();

      expect(backed, isTrue);
    });
  });

  _wiring();

  group('the scanner chrome', () {
    testWidgets('is gone, not merely overdrawn', (t) async {
      // The whole point: the frame and the torch are instructions for an
      // action the screen has just said is impossible.
      await t.pumpWidget(host(CameraBlocked(
        message: 'jperg needs your camera to scan a QR code.',
        onOpenSettings: () {},
        onBack: () {},
      )));

      expect(find.byIcon(Icons.flash_off_rounded), findsNothing);
      expect(find.byIcon(Icons.flash_on_rounded), findsNothing);
      expect(find.textContaining('Point your camera'), findsNothing);
    });
  });
}

void _noop() {}

/// The page is wired to the screen above.
///
/// Asserted against the source because driving it needs the scanner plugin's
/// platform channel to answer with a refusal, and what could plausibly break
/// is not the rendering — it is the wiring being removed, or the whole-page
/// stand-down being reduced back to the plugin's inner `errorBuilder`, which
/// is the shape that produced the bug.
void _wiring() {
  group('QrScanPage', () {
    final source =
        File('lib/features/home/presentation/pages/qr_scan_page.dart')
            .readAsStringSync();

    test('hands a refused camera to the shared screen', () {
      expect(source, contains('CameraBlocked('));
      expect(source, contains('errorBuilder'));
    });

    test('offers Settings only for a refusal', () {
      expect(source, contains('MobileScannerErrorCode.permissionDenied'));
      expect(source, contains('openAppSettings'));
    });

    test('stands the whole page down, not just the camera layer', () {
      // `errorBuilder` replaces the camera *inside* the Stack; the scan frame
      // and the torch are drawn over it. Returning early is what takes them
      // away — without this the error sits under a working-looking scanner.
      expect(source, contains('if (_cameraError != null) {'));
    });

    test('does not put the plugin exception on screen', () {
      expect(source, isNot(contains('error.toString()')));
      expect(source, contains('_messageFor('));
    });
  });
}
