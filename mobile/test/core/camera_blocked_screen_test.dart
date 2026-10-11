/// What the selfie screen shows when there is no camera to show.
///
/// The refusal used to be drawn *into* the capture screen: the message landed
/// across the "Take a Selfie" title, with "Centre your face inside the oval"
/// and a live shutter button underneath it. Three instructions for an action
/// the same screen had just said was impossible, and a button whose only
/// outcome was failure.
///
/// The camera channel is mocked rather than left unimplemented: an unanswered
/// platform call never completes in a widget test, so the screen would sit on
/// its spinner and the state under test would never be reached. Answering the
/// call with the error a refused camera actually produces is what makes this
/// the real path.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/selfie_capture_screen.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/camera');

  /// Answers `availableCameras` with [code], the way a refused or broken
  /// camera does. The plugin turns a PlatformException into a CameraException
  /// carrying the same code, which is what the screen branches on.
  void mockCamera(WidgetTester t, {required String code}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: code, message: 'mocked');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
  }

  Future<void> pumpScreen(WidgetTester t, {required String code}) async {
    mockCamera(t, code: code);
    await t.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: const SelfieCaptureScreen(),
        ),
      ),
    );
    // Pumped rather than settled: until the error lands the screen is a
    // CircularProgressIndicator, which animates forever, so pumpAndSettle
    // times out instead of settling.
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  group('when the camera is refused', () {
    testWidgets('the capture chrome is gone, not merely overdrawn', (t) async {
      await pumpScreen(t, code: 'CameraAccessDenied');

      expect(find.text('Take a Selfie'), findsNothing,
          reason: 'the title promises an action that cannot happen');
      expect(find.text('Centre your face inside the oval'), findsNothing,
          reason: 'there is no oval, and no face to centre in it');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'it is not still starting — it has failed');
    });

    testWidgets('it offers a way into Settings', (t) async {
      await pumpScreen(t, code: 'CameraAccessDenied');

      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('and a way back out', (t) async {
      // The screen is pushed, so leaving has to be possible without a camera
      // — otherwise a refusal is a dead end.
      await pumpScreen(t, code: 'CameraAccessDenied');
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('when the camera is simply broken', () {
    testWidgets('it explains, but does not send anyone to Settings',
        (t) async {
      // A camera in use, a simulator, a failing device: nothing a permission
      // switch can fix, so offering the switch would be wrong advice.
      await pumpScreen(t, code: 'CameraError');

      expect(find.text('Take a Selfie'), findsNothing);
      expect(find.text('Open Settings'), findsNothing);
      expect(find.text('The camera could not be started.'), findsOneWidget);
    });
  });
}
