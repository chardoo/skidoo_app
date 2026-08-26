import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/jperg_logo.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/pending_interests_usecases.dart';
import 'package:jperg_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/resend_verification_usecase.dart';
import 'package:jperg_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:jperg_app/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:jperg_app/features/auth/presentation/pages/login_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/signup_page.dart';
import 'package:jperg_app/l10n/app_localizations.dart';

/// Stand-ins for the use cases the blocs are built from.
///
/// `implements` with a `noSuchMethod` body rather than real fakes: the login
/// use case alone pulls in a repository, the auth service, the chat database
/// and two key services, none of which a form that is never submitted has any
/// use for. Nothing here is ever called.
///
/// One class each rather than one implementing all four — they each declare a
/// `call` with a different signature, and a single class cannot satisfy them
/// all.
mixin _Unused {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _FakeLogin with _Unused implements LoginUseCase {}

class _FakePendingInterests with _Unused implements GetPendingInterestsUseCase {}

class _FakeResend with _Unused implements ResendVerificationUseCase {}

class _FakeRegister with _Unused implements RegisterUseCase {}

/// The first screen anybody sees.
///
/// It carried a generic camera glyph in a gradient tile — artwork that says
/// "photo app" rather than which one — and offered no way past the gate except
/// the Back button, even though the signed-out feed is a real destination and
/// sign-up has always linked to it.
///
/// The logo is asserted as centred rather than merely present: it sits in a
/// left-aligned column, so it only lands in the middle because of the Align
/// wrapped round it, and that is exactly the sort of thing a later edit
/// removes without noticing.
Widget host(Widget page) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        // Both screens read their copy through AppLocalizations.of(context)!,
        // which is null without these — the bang then takes the page down
        // before anything renders.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
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

    if (sl.isRegistered<LoginBloc>()) sl.unregister<LoginBloc>();
    if (sl.isRegistered<SignUpBloc>()) sl.unregister<SignUpBloc>();
    sl.registerFactory<LoginBloc>(() => LoginBloc(
          loginUseCase: _FakeLogin(),
          getPendingInterests: _FakePendingInterests(),
          resendVerification: _FakeResend(),
        ));
    sl.registerFactory<SignUpBloc>(
      () => SignUpBloc(registerUseCase: _FakeRegister()),
    );
  });

  tearDown(() => sl.reset());

  group('login', () {
    testWidgets('wears the jperg logo, not a stock camera icon',
        (tester) async {
      await tester.pumpWidget(host(const LoginPage()));
      await tester.pump();

      expect(find.byType(JpergLogo), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
    });

    testWidgets('centres the logo above the left-aligned copy',
        (tester) async {
      await tester.pumpWidget(host(const LoginPage()));
      await tester.pump();

      final logo = tester.getCenter(find.byType(JpergLogo));
      final screen = tester.getSize(find.byType(MaterialApp)).width;
      expect(
        logo.dx,
        moreOrLessEquals(screen / 2, epsilon: 1.0),
        reason: 'the Align around the logo is what puts it here',
      );
    });

    testWidgets('offers a way past the gate', (tester) async {
      await tester.pumpWidget(host(const LoginPage()));
      await tester.pump();

      expect(find.text('Continue as guest'), findsOneWidget);
    });
  });

  group('signup', () {
    testWidgets('wears the same logo, centred', (tester) async {
      await tester.pumpWidget(host(const SignUpPage()));
      await tester.pump();

      expect(find.byType(JpergLogo), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);

      final logo = tester.getCenter(find.byType(JpergLogo));
      final screen = tester.getSize(find.byType(MaterialApp)).width;
      expect(logo.dx, moreOrLessEquals(screen / 2, epsilon: 1.0));
    });
  });
}
