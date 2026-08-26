import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_inline_banner.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:jperg_app/features/auth/domain/usecases/resend_verification_usecase.dart';
import 'package:jperg_app/features/auth/presentation/pages/email_verification_page.dart';

/// "Resend code" on the verification screen used to start a thirty-second
/// cooldown, announce that a code was on its way, and call nothing at all — so
/// the one escape hatch for a code that never arrived was a timer with a
/// message attached. The screen also had no way back, which mattered because
/// the likeliest reason a code never arrives is a typo in the email address
/// fixed on the screen in front of you.

class _UnusedRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the resend path must not touch the repository');
}

class _RecordingResend extends ResendVerificationUseCase {
  _RecordingResend({this.fails = false}) : super(_UnusedRepo());

  final bool fails;
  final List<String> calls = [];

  @override
  Future<void> call(String email) async {
    calls.add(email);
    if (fails) throw Exception('network down');
  }
}

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: child,
      ),
    );

/// Steps past the 30-second cooldown the screen opens with — a code has just
/// been sent when you arrive, so the button starts disabled by design.
Future<void> waitOutCooldown(WidgetTester tester) async {
  for (var i = 0; i < 31; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  late _RecordingResend resend;

  setUp(() {
    // The default 800x600 test surface is not a phone: ScreenUtil scales the
    // six code boxes for an 800-wide window while the page caps its content at
    // 480, so the row overflows on a viewport no device has.
    TestWidgetsFlutterBinding.ensureInitialized();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> pumpPage(WidgetTester tester, {bool fails = false}) async {
    resend = _RecordingResend(fails: fails);
    GetIt.I.registerSingleton<ResendVerificationUseCase>(resend);
    await tester.pumpWidget(
      host(const EmailVerificationPage(email: 'ada@example.com')),
    );
    await tester.pump();
  }

  tearDown(() async => GetIt.I.reset());

  testWidgets('resend actually asks the backend for a new code',
      (tester) async {
    await pumpPage(tester);
    await waitOutCooldown(tester);

    await tester.tap(find.text("Didn't receive it? Resend code"));
    await tester.pump();
    await tester.pump();

    expect(resend.calls, ['ada@example.com'],
        reason: 'the button must send a request, not just start a timer');
  });

  testWidgets('a sent code is confirmed in the banner', (tester) async {
    await pumpPage(tester);
    await waitOutCooldown(tester);

    await tester.tap(find.text("Didn't receive it? Resend code"));
    await tester.pump();
    await tester.pump();

    final banner = tester.widget<AppInlineBanner>(find.byType(AppInlineBanner));
    expect(banner.kind, AppBannerKind.success);
    expect(banner.message, contains('ada@example.com'));
  });

  testWidgets('a failed resend says so, and stays retryable', (tester) async {
    await pumpPage(tester, fails: true);
    await waitOutCooldown(tester);

    await tester.tap(find.text("Didn't receive it? Resend code"));
    await tester.pump();
    await tester.pump();

    final banner = tester.widget<AppInlineBanner>(find.byType(AppInlineBanner));
    expect(banner.kind, AppBannerKind.error);
    // The cooldown starts only once the server has taken the request, so a
    // request that never landed must not lock the button for thirty seconds.
    expect(find.text("Didn't receive it? Resend code"), findsOneWidget);
  });

  testWidgets('the screen has a way back to sign up', (tester) async {
    await pumpPage(tester);

    expect(find.byType(AppBackButton), findsOneWidget);
  });

  testWidgets('typing a fresh code clears the resend banner', (tester) async {
    await pumpPage(tester);
    await waitOutCooldown(tester);
    await tester.tap(find.text("Didn't receive it? Resend code"));
    await tester.pump();
    await tester.pump();
    expect(find.byType(AppInlineBanner), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1');
    await tester.pump();

    expect(find.byType(AppInlineBanner), findsNothing);
  });
}
