import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:jperg_app/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:jperg_app/features/auth/presentation/pages/signup_page.dart';
import 'package:jperg_app/l10n/app_localizations.dart';

/// A field complains about itself and about nothing else.
///
/// Sign-up put `autovalidateMode: onUserInteraction` on the **`Form`**, which
/// is a different setting from the same name on a field. `FormState`'s
/// "has the user interacted" is `_fields.any(...)`, and the `_validate()` it
/// then runs writes an `errorText` onto every field the form owns regardless
/// of that field's own mode. So the first character typed into the email box
/// — or one paste into it — put a red error under the four fields nobody had
/// reached yet, which reads as a broken form before you have finished the
/// first line of it.
///
/// `password_live_validation_test` exercised the same setting and passed,
/// because its fixture is a form with **one** field: where there is only one,
/// "any field was touched" and "this field was touched" cannot be told apart.
/// These use the real page, with its five.
mixin _Unused {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _FakeRegister with _Unused implements RegisterUseCase {}

Widget host(Widget page) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        // The page reads its copy through `AppLocalizations.of(context)!`.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    );

/// Every validator on this form prefixes its message with `*`, so this is
/// "how many fields are currently complaining" without naming each message.
Finder get _errors => find.textContaining('*');

/// The inputs in the order the page lays them out: email, username, phone,
/// password, confirm. Asserted in [_pumpSignup] so a reordered form fails
/// here rather than silently testing the wrong box.
const _email = 0;
const _username = 1;
const _password = 3;
const _confirm = 4;

Future<void> _pumpSignup(WidgetTester t) async {
  await t.pumpWidget(host(const SignUpPage()));
  await t.pump();
  expect(find.byType(TextField), findsNWidgets(5),
      reason: 'email, username, phone, password, confirm');
}

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

  testWidgets('a pristine form says nothing', (t) async {
    await _pumpSignup(t);

    expect(_errors, findsNothing);
  });

  testWidgets('typing a valid email leaves the other four fields alone',
      (t) async {
    await _pumpSignup(t);

    await t.enterText(find.byType(TextField).at(_email), 'jane@example.com');
    await t.pump();

    // The regression: this found four errors — username, phone, password and
    // confirm — under boxes that were still empty and never touched.
    expect(_errors, findsNothing);
  });

  testWidgets('and so does pasting one in', (t) async {
    await _pumpSignup(t);

    // A paste is one change carrying the whole value, which is exactly what
    // `enterText` does — the same single `didChange` that typing one character
    // produces, and so the same form-wide validation it used to trigger.
    await t.enterText(find.byType(TextField).at(_email), 'jane@example.com');
    await t.pump();

    expect(_errors, findsNothing);
  });

  testWidgets('a half-typed email still reports itself, and only itself',
      (t) async {
    await _pumpSignup(t);

    await t.enterText(find.byType(TextField).at(_email), 'jane@');
    await t.pump();

    // Validating as you type is the point — it is only the *other* fields
    // that had no business being flagged.
    expect(find.text('*Invalid email'), findsOneWidget);
    expect(_errors, findsOneWidget);
  });

  testWidgets('a field emptied after being typed into does complain',
      (t) async {
    await _pumpSignup(t);

    await t.enterText(find.byType(TextField).at(_username), 'jane');
    await t.pump();
    expect(_errors, findsNothing);

    await t.enterText(find.byType(TextField).at(_username), '');
    await t.pump();

    // Touched and now empty: this one has earned its error.
    expect(find.text('*Required'), findsOneWidget);
    expect(_errors, findsOneWidget);
  });

  testWidgets('editing the password clears a stale mismatch on confirm',
      (t) async {
    await _pumpSignup(t);

    // Filling confirm first is the case per-field validation could plausibly
    // get wrong: the complaint belongs to this field, but what resolves it is
    // typing in a *different* one.
    await t.enterText(find.byType(TextField).at(_confirm), 'Abcdefgh1!');
    await t.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
    // ...and the password box above, still untouched, keeps quiet about it.
    expect(_errors, findsNothing);

    await t.enterText(find.byType(TextField).at(_password), 'Abcdefgh1!');
    await t.pump();

    // Every field rebuilds when any one of them changes, so an already-touched
    // confirm re-runs its comparison and the mismatch goes. Without that, the
    // form would sit there insisting the passwords differ when they do not.
    expect(find.text('Passwords do not match'), findsNothing);
    expect(_errors, findsNothing);
  });
}
