import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/face_gate_prompt.dart';

/// "Continue as guest" lands on DiscoveryPage — a different page from the
/// signed-in HomeNavigationPage — and that page used to carry a logo +
/// "Sign up / Log in" bar with no tabs at all. These lock in the guest shell
/// the designs call for: Found | Explore, with Found showing the face gate.
///
/// The page itself needs DiscoveryBloc and the service locator, so this covers
/// the pieces that can be rendered standalone; the wiring between them is
/// exercised by running the app.
Widget host(AppThemeExtension ext, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [ext]),
        home: Scaffold(body: child),
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

  for (final (name, ext) in [
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    testWidgets('guest Found gate renders in $name mode', (t) async {
      await t.pumpWidget(host(
        ext,
        FaceGatePrompt(
          reason: FaceGateReason.signedOut,
          onPrimaryAction: () {},
          onSignIn: () {},
        ),
      ));
      await t.pump();

      expect(find.text('Add your face to get found'), findsOneWidget);
      expect(find.text('Add my face'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      // Headline must not be painted in the other theme's ink — the bug that
      // makes a screen look blank.
      final headline =
          t.widget<Text>(find.text('Add your face to get found'));
      expect(headline.style!.color, ext.greetingColor);
    });
  }
}
