import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/presentation/pages/face_capture_step_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// This page is both step 1 of the sign-up wizard and a standalone errand for
/// an existing user who only lacks a selfie. The bug these guard: the second
/// case used to inherit the first's ending, so adding a face from the Found
/// tab dropped the user into "what best describes you" and the rest of account
/// setup they had already completed.
class _FakeAuth extends AuthService {
  @override
  Future<String> getName() async => 'Ama';
}

Widget host(Widget child, {VoidCallback? onPopped}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        // NoSplash: the default ink sparkle loads a fragment shader the test
        // harness can't decode on this Flutter version, which throws on any
        // Material tap. The splash is not what's under test.
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => child));
                  onPopped?.call();
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
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
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    sl.registerSingleton<AuthService>(_FakeAuth());
  });

  tearDown(() {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
  });

  testWidgets('standalone: skipping returns to the caller, not the wizard',
      (t) async {
    var returned = false;
    await t.pumpWidget(host(
      const FaceCaptureStepPage(standalone: true),
      onPopped: () => returned = true,
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Add your face'), findsOneWidget);

    // "Skip" is the path that used to continue into account setup.
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();

    expect(returned, isTrue, reason: 'should pop back to the Found tab');
    expect(find.text('Add your face'), findsNothing);
  });

  testWidgets('standalone hides the wizard step counter', (t) async {
    await t.pumpWidget(host(const FaceCaptureStepPage(standalone: true)));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    // "1 of 4" would promise three more screens that never come.
    expect(find.textContaining('of 4'), findsNothing);
  });

  testWidgets('wizard mode still shows the step counter', (t) async {
    await t.pumpWidget(host(const FaceCaptureStepPage()));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Add your face'), findsOneWidget);
  });
}
