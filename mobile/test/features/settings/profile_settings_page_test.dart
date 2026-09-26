import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/settings/presentation/pages/profile_settings_page.dart';
import 'package:jperg_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Settings → Profile, which is now a page rather than a jump straight into
/// the editor.
///
/// Profile and Portfolio are the two halves of "how you present yourself" and
/// used to sit at opposite ends of a scrolling Settings list — Portfolio under
/// a *Photographer* heading of its own, several sections down. They are
/// together here.
///
/// The role is the part worth pinning: a viewer has no portfolio, and the
/// page must not offer a creator-setup screen to somebody who is not one.

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: child,
      ),
    );

Finder rowLabelled(String label) => find.descendant(
      of: find.byType(SettingsRow),
      matching: find.text(label),
    );

void main() {
  final wasRole = AuthService.role.value;

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    AuthService.role.value = wasRole;
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('a creator gets both halves in one place', (t) async {
    AuthService.role.value = 'photographer';

    await t.pumpWidget(host(const ProfileSettingsPage()));
    await t.pump();

    expect(rowLabelled('Profile'), findsOneWidget);
    expect(rowLabelled('Portfolio'), findsOneWidget);
    // Nothing is edited on this page — both rows push the screen that does.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a viewer is never offered a portfolio', (t) async {
    // PortfolioEditPage is where somebody becomes a creator. Showing the row
    // to an account that is not one puts a setup wizard behind a settings row
    // that reads like an edit screen.
    AuthService.role.value = 'user';

    await t.pumpWidget(host(const ProfileSettingsPage()));
    await t.pump();

    expect(rowLabelled('Profile'), findsOneWidget);
    expect(rowLabelled('Portfolio'), findsNothing);
  });

  testWidgets('becoming a creator fills the row in without a restart',
      (t) async {
    // The creator wizard is reachable from Account & Security, two taps from
    // here, so the role really does move while this page is on the stack.
    AuthService.role.value = 'user';
    await t.pumpWidget(host(const ProfileSettingsPage()));
    await t.pump();
    expect(rowLabelled('Portfolio'), findsNothing);

    AuthService.role.value = 'photographer';
    await t.pump();

    expect(rowLabelled('Portfolio'), findsOneWidget);
  });

  group('the row that opens it', () {
    test('a viewer still goes straight to the editor', () {
      // Otherwise the hub is a single row called Profile opening a page called
      // Profile — a tap that exists only to be got past.
      AuthService.role.value = 'user';
      expect(ProfileSettingsPage.isWorthShowing, isFalse);

      AuthService.role.value = 'photographer';
      expect(ProfileSettingsPage.isWorthShowing, isTrue);
    });

    test('Portfolio is gone from the Settings list itself', () {
      // It moved; it did not get copied. Two doors to one editor, one of them
      // under a heading that no longer has anything else beneath it, is how
      // the list got long enough to need this page.
      final source = File(
        'lib/features/settings/presentation/pages/settings_page.dart',
      ).readAsStringSync();

      expect(source, isNot(contains("label: 'Portfolio'")));
      expect(source, isNot(contains("title: 'Photographer'")));
      expect(source, contains('ProfileSettingsPage'));
    });
  });
}
