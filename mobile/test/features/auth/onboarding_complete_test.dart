import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/presentation/pages/onboarding_complete_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The face step is skippable, so this screen is reached with and without a
/// selfie on file. Only one of those has a scan running — the other used to be
/// told "We're scanning photos for your face", describing work that wasn't
/// happening, above a box containing the mock's placeholder label.
class _FakeAuth extends AuthService {
  @override
  Future<String> getName() async => 'Joe';
}

Widget host() => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        home: const OnboardingCompletePage(),
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
    AuthService.hasAddedFaces.value = false;
  });

  testWidgets('no face: greeting only — no scanning claim, no loader',
      (t) async {
    AuthService.hasAddedFaces.value = false;
    await t.pumpWidget(host());
    await t.pump();

    expect(find.text("You're all set, Joe!"), findsOneWidget);
    expect(find.text('Go home'), findsOneWidget);

    expect(find.textContaining('scanning'), findsNothing);
    expect(find.textContaining('Scanning'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('face added: keeps the scanning message and a real loader',
      (t) async {
    AuthService.hasAddedFaces.value = true;
    await t.pumpWidget(host());
    await t.pump();

    expect(find.text("You're all set, Joe!"), findsOneWidget);
    expect(find.textContaining("We're scanning photos for your face"),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the mock placeholder label never ships', (t) async {
    for (final hasFace in [true, false]) {
      AuthService.hasAddedFaces.value = hasFace;
      await t.pumpWidget(host());
      await t.pump();
      expect(find.text('Loader for scanning photos'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    }
  });
}
