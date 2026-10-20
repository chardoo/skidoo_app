import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:jperg_app/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:jperg_app/features/auth/presentation/pages/signup_page.dart';
import 'package:jperg_app/l10n/app_localizations.dart';

/// What sign-up's second field asks for.
///
/// It was labelled "Username" and hinted "e.g. jane_doe", and the value went
/// straight into the `name` field of the create-account request — so somebody
/// typing `jane_doe` had it printed as their name under their avatar on every
/// screen, while their actual handle was derived from it behind their back.
///
/// The handle is generated server-side from the email now (`User.username` —
/// see the backend's app/utils/username.py) and is never typed into this form,
/// so the field asks for the one thing it was always collecting.
///
/// Pinned because this is a rename that has to reach four places at once — the
/// label, the hint, the controller and the event field. A rename that reaches
/// three leaves sign-up posting the wrong thing, which is the bug it is
/// replacing.
mixin _Unused {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _FakeRegister with _Unused implements RegisterUseCase {}

Widget _host(Widget page) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
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

    if (sl.isRegistered<SignUpBloc>()) sl.unregister<SignUpBloc>();
    sl.registerFactory<SignUpBloc>(
      () => SignUpBloc(registerUseCase: _FakeRegister()),
    );
  });

  tearDown(() => sl.reset());

  testWidgets('the field is labelled Name, not Username', (t) async {
    await t.pumpWidget(_host(const SignUpPage()));
    await t.pump();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
  });

  testWidgets('and its hint is a name rather than a handle', (t) async {
    await t.pumpWidget(_host(const SignUpPage()));
    await t.pump();

    expect(find.text('e.g. Jane Doe'), findsOneWidget);
    // The old hint. A handle is not something this form collects any more.
    expect(find.text('e.g. jane_doe'), findsNothing);
  });

  testWidgets('nothing on the form asks for a handle at all', (t) async {
    await t.pumpWidget(_host(const SignUpPage()));
    await t.pump();

    // Five fields: email, name, phone, password, confirm. A sixth would mean
    // somebody put the handle back.
    expect(find.byType(TextField), findsNWidgets(5));
    expect(find.textContaining('sername'), findsNothing);
    expect(find.textContaining('andle'), findsNothing);
  });
}
