import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/config/app_links_config.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/home/presentation/widgets/creator_mode_menu.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The mode switcher is the photographer's way from the feed to the half of
/// their account that lives on the web. Everyone else must not see it: a client
/// has no second mode, so the control would open a menu with nothing in it.

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(body: Center(child: child)),
      ),
    );

Future<void> signInAs(String role, {String profileUrl = ''}) async {
  // AuthService keeps these in the keychain on mobile, not SharedPreferences —
  // mocking the wrong backend reads back null and every role looks like a guest.
  FlutterSecureStorage.setMockInitialValues({
    'auth.role': role,
    'auth.profile_url': profileUrl,
  });
  if (GetIt.I.isRegistered<AuthService>()) {
    await GetIt.I.reset();
  }
  final auth = AuthService();
  GetIt.I.registerSingleton<AuthService>(auth);
  // Signing in is what publishes the role, and the menu watches the published
  // value rather than reading storage — that is the whole point of it, so a
  // helper that only seeded storage would be testing a path nothing uses.
  await auth.primeRole();
}

void main() {
  tearDown(() async {
    AuthService.role.value = '';
    await GetIt.I.reset();
  });

  testWidgets('a photographer gets the switcher', (t) async {
    await signInAs('photographer');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('a client gets nothing at all', (t) async {
    await signInAs('user');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });

  testWidgets('a known role draws on the very first frame', (t) async {
    // This used to assert the opposite — nothing until an async read came
    // back — because the role was only reachable through a Future. The bar's
    // trailing edge visibly reflowed on every feed open as a result. The role
    // is a value now, primed before the first frame, so there is nothing to
    // wait for and nothing to reflow.
    await signInAs('photographer');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    // Deliberately no settle: this is the first frame.
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('upgrading mid-session brings the switcher in', (t) async {
    // The reported bug: a client became a creator and the top bar went on
    // showing them nothing, because this widget was built before the upgrade
    // and had already read the role.
    await signInAs('user');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

    await GetIt.I<AuthService>().setRole('photographer');
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('tapping opens the two modes from the design', (t) async {
    await signInAs('photographer');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();

    await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await t.pumpAndSettle();

    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Creator Dashboard'), findsOneWidget);
    // Explorer is the mode they are already in — ticked, not a destination.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // The dashboard leaves the app; say so before the tap.
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
  });

  testWidgets('the menu closes when dismissed', (t) async {
    await signInAs('photographer');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();

    await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await t.pumpAndSettle();
    expect(find.text('Creator Dashboard'), findsOneWidget);

    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.text('Creator Dashboard'), findsNothing);
  });

  test('the dashboard points at the public domain', () {
    // It was a hardcoded picco-v2.onrender.com preview URL, which is not where
    // anyone should be sent.
    expect(AppLinksConfig.creatorDashboardUrl,
        'https://jperg.com/photographer/dashboard');
    expect(AppLinksConfig.creatorDashboardUrl,
        startsWith(AppLinksConfig.shareBaseUrl));
  });
}
