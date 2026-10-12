import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/config/app_links_config.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/home/presentation/widgets/creator_mode_menu.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import '../../support/icon_finders.dart';

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

    expect(findAppIcon(AppIcons.caretDown), findsOneWidget);
  });

  testWidgets('a client gets nothing at all', (t) async {
    await signInAs('user');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();

    expect(findAppIcon(AppIcons.caretDown), findsNothing);
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
    expect(findAppIcon(AppIcons.caretDown), findsOneWidget);
  });

  testWidgets('upgrading mid-session brings the switcher in', (t) async {
    // The reported bug: a client became a creator and the top bar went on
    // showing them nothing, because this widget was built before the upgrade
    // and had already read the role.
    await signInAs('user');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();
    expect(findAppIcon(AppIcons.caretDown), findsNothing);

    await GetIt.I<AuthService>().setRole('photographer');
    await t.pumpAndSettle();

    expect(findAppIcon(AppIcons.caretDown), findsOneWidget);
  });

  testWidgets('tapping opens the two modes from the design', (t) async {
    await signInAs('photographer');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();

    await t.tap(findAppIcon(AppIcons.caretDown));
    await t.pumpAndSettle();

    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Creator Dashboard'), findsOneWidget);
    // Explorer is the mode they are already in — ticked, not a destination.
    expect(findAppIcon(AppIcons.check), findsOneWidget);
    // The dashboard leaves the app; say so before the tap.
    expect(findAppIcon(AppIcons.externalLink), findsOneWidget);
  });

  testWidgets('the menu closes when dismissed', (t) async {
    await signInAs('photographer');
    await t.pumpWidget(host(const CreatorModeMenu(overSolidBackground: false)));
    await t.pumpAndSettle();

    await t.tap(findAppIcon(AppIcons.caretDown));
    await t.pumpAndSettle();
    expect(find.text('Creator Dashboard'), findsOneWidget);

    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.text('Creator Dashboard'), findsNothing);
  });

  group('where the web links point', () {
    test('the portal opens on production', () {
      // It opened on the Render deployment while the dashboard was being
      // built. Production carries it now — the live jperg.com bundle
      // references every PhotographerView chunk — so creators are sent to the
      // portal that has been deployed rather than to a build server.
      expect(AppLinksConfig.creatorDashboardUrl,
          'https://jperg.com/photographer/dashboard');
      expect(AppLinksConfig.creatorUploadUrl,
          'https://jperg.com/photographer/events');
    });

    test('shares are built on jperg.com, and that is not a coincidence', () {
      // The two agree again, which is fine — but only one of them is *pinned*.
      // This host appears in two places outside Dart: `applinks:jperg.com` in
      // Runner.entitlements and `deepLinkHost` in build.gradle.kts. A link
      // built on any other host opens a browser instead of the app, silently.
      expect(AppLinksConfig.shareBaseUrl, 'https://jperg.com');
    });

    test('and the portal is still the one that is allowed to move', () {
      // They were deliberately different for a while and may be again: the
      // portal is a destination the app only ever opens, so it can point at
      // whichever deployment is being worked on. Moving it is this one line.
      // Moving shareBaseUrl is a release of both platforms.
      expect(AppLinksConfig.webPortalUrl, AppLinksConfig.shareBaseUrl,
          reason: 'today they agree');
      expect(AppLinksConfig.creatorDashboardUrl,
          startsWith(AppLinksConfig.webPortalUrl));
    });
  });
}
