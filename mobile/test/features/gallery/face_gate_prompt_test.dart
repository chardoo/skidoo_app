import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/face_gate_prompt.dart';

/// The point of this widget is that one panel serves two different states, so
/// what's worth locking down is where they diverge: the signed-out gate offers
/// a way back to an existing account, the no-face gate must not — that user is
/// already signed in and a "Sign in" link would be nonsense.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

void main() {
  // The default 800x600 test surface makes ScreenUtil scale every .sp value
  // against a 390dp design width, roughly doubling the layout and pushing the
  // button off-screen. Size the surface like the phone the design targets.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('signed out: offers sign-up and a sign-in link', (tester) async {
    var primaryTaps = 0;
    var signInTaps = 0;

    await tester.pumpWidget(host(FaceGatePrompt(
      reason: FaceGateReason.signedOut,
      onPrimaryAction: () => primaryTaps++,
      onSignIn: () => signInTaps++,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Add your face to get found'), findsOneWidget);
    expect(find.text('Add my face'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('Add my face'));
    await tester.tap(find.text('Sign in'));
    expect(primaryTaps, 1);
    expect(signInTaps, 1);
  });

  testWidgets('no face added: same panel, no sign-in link', (tester) async {
    var primaryTaps = 0;

    await tester.pumpWidget(host(FaceGatePrompt(
      reason: FaceGateReason.noFaceAdded,
      onPrimaryAction: () => primaryTaps++,
    )));
    await tester.pumpAndSettle();

    // Same headline — the user is missing a face either way.
    expect(find.text('Add your face to get found'), findsOneWidget);
    // ...but the action is named for the one step they have left, per the
    // signed-in design, rather than the guest's broader "Add my face".
    expect(find.text('Take a selfie'), findsOneWidget);
    expect(find.text('Add my face'), findsNothing);
    // ...and they are already signed in.
    expect(find.text('Sign in'), findsNothing);
    expect(find.textContaining('Already have an account'), findsNothing);

    await tester.tap(find.text('Take a selfie'));
    expect(primaryTaps, 1);
  });

  testWidgets('a stray onSignIn is ignored when a face is all that is missing',
      (tester) async {
    await tester.pumpWidget(host(FaceGatePrompt(
      reason: FaceGateReason.noFaceAdded,
      onPrimaryAction: () {},
      onSignIn: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('copy can be overridden for other face prompts', (tester) async {
    await tester.pumpWidget(host(FaceGatePrompt(
      reason: FaceGateReason.noFaceAdded,
      onPrimaryAction: () {},
      title: 'We could not match you',
      subtitle: 'Try a clearer selfie.',
      actionLabel: 'Retake selfie',
    )));
    await tester.pumpAndSettle();

    expect(find.text('We could not match you'), findsOneWidget);
    expect(find.text('Try a clearer selfie.'), findsOneWidget);
    expect(find.text('Retake selfie'), findsOneWidget);
    expect(find.text('Add my face'), findsNothing);
  });
}
