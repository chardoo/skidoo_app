import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:jperg_app/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_profile_page.dart';
import 'package:jperg_app/services/auth_service.dart';

// A creator's profile is a signed-in destination.
//
// It carries their portfolio, their rates, and the buttons to follow and
// message them — none of which a guest can act on. The guest feed already
// trades every other tap for a login sheet: the album, the reactions, the more
// menu. The avatar was the one that went straight through, so a guest could
// browse creator profiles the long way round while being asked to sign in for
// everything else on the same card.
//
// openPhotographerProfile is where that is decided, because it is the one
// helper every avatar and creator pin in the app goes through — the feed, the
// older discovery card, search, Following, the comment threads. Pinning the
// gate there is what makes it hold for the callers added after this was
// written.

/// Stands in for the credential store, signed in or out on demand.
class _FakeAuth extends AuthService {
  _FakeAuth(this._token);

  final String _token;

  @override
  Future<String> getToken() async => _token;
}

/// Enough of a [LoginBloc] for the sheet to build. Nothing here signs anybody
/// in — what is being tested is which of the two things a tap produces, not
/// what happens after the sheet is filled in.
class _FakeLoginBloc extends Bloc<LoginEvent, LoginState> implements LoginBloc {
  _FakeLoginBloc() : super(const LoginState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Loads the real DM Sans metrics.
///
/// The default test font gives every glyph the same square advance, roughly
/// double DM Sans' width — enough to overflow the login sheet's "Don't have an
/// account? Sign up" row on a phone-width surface. That is an artefact of the
/// font, not something the sheet does on a device, and it would fail these
/// tests for a reason that has nothing to do with what they assert.
Future<void> loadBodyFont() async {
  final loader = FontLoader(Styles.bodyFontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(Future.value(ByteData.sublistView(
        File('assets/fonts/DMSans-$weight.ttf').readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(loadBodyFont);

  /// Signed in or out, as far as anything asking [AuthService] can tell.
  void signedIn(bool value) {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    sl.registerSingleton<AuthService>(_FakeAuth(value ? 'a.token' : ''));
  }

  setUp(() {
    // A phone, not the 800x600 the test binding defaults to. ScreenUtil scales
    // every `.w` in the login sheet against the 390 design width, so on the
    // default surface the sheet lays itself out half as wide again as it has
    // room for and overflows before it can be asserted on.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    if (!sl.isRegistered<LoginBloc>()) {
      sl.registerFactory<LoginBloc>(() => _FakeLoginBloc());
    }
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();

    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    if (sl.isRegistered<LoginBloc>()) sl.unregister<LoginBloc>();
  });

  Future<void> pumpTapTarget(WidgetTester t) => t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(
            // The real font, so the sheet measures the way it does on a phone.
            textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: Styles.bodyFontFamily,
                ),
            extensions: [AppThemeExtension.dark],
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openPhotographerProfile(
                  context,
                  photographerId: 'p1',
                  photographerName: 'Kwame Studios',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

  testWidgets('a guest is asked to sign in instead of getting the profile',
      (t) async {
    signedIn(false);
    await pumpTapTarget(t);

    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.byType(CreatorProfilePage), findsNothing,
        reason: 'a signed-out viewer reached a creator profile');
    expect(find.byType(LoginBottomSheet), findsOneWidget,
        reason: 'the tap has to go somewhere — it asks for an account');
  });

  testWidgets('a signed-in viewer goes straight through', (t) async {
    signedIn(true);
    await pumpTapTarget(t);

    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.byType(CreatorProfilePage), findsOneWidget);
    expect(find.byType(LoginBottomSheet), findsNothing,
        reason: 'the gate must not stand in the way of an account that exists');
  });

  testWidgets('an empty id opens nothing at all', (t) async {
    // Guards the early return: an event with no photographer on it must not
    // turn a tap into a login prompt for a person who does not exist.
    signedIn(false);
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openPhotographerProfile(
                context,
                photographerId: '',
                photographerName: '',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.byType(CreatorProfilePage), findsNothing);
    expect(find.byType(LoginBottomSheet), findsNothing);
  });
}
