import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/settings/presentation/pages/change_password_page.dart';

/// Changing your password, on a screen with room for it.
///
/// It used to be an [AlertDialog] with two bare [TextField]s in it: no
/// confirmation field, no rules checked before the request, and a keyboard
/// covering most of what was left. The tests here are about what the page has
/// that the dialog could not — everything below refuses to call the endpoint,
/// which is the point. A password change that reaches the server and comes
/// back "invalid" has already cost a round trip and told the user nothing they
/// could not have been told while typing.

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: child,
      ),
    );

/// The nth password field on screen — current, new, confirm, in order.
///
/// By [TextField]: [AppTextField] is a [FormField] wrapping one, rather than a
/// `TextFormField`, so the latter finds nothing here.
Finder fieldAt(int index) => find.byType(TextField).at(index);

Future<void> fill(
  WidgetTester t, {
  required String current,
  required String next,
  required String confirm,
}) async {
  await t.enterText(fieldAt(0), current);
  await t.enterText(fieldAt(1), next);
  await t.enterText(fieldAt(2), confirm);
  await t.pump();
}

Future<void> submit(WidgetTester t) async {
  // Scrolled to first: three fields and a banner push the button under the
  // fold on a 390x844 surface, and a tap that misses would leave these tests
  // passing on the autovalidation alone.
  await t.ensureVisible(find.text('Update password'));
  await t.pump();
  await t.tap(find.text('Update password'));
  await t.pump();
}

void main() {
  testWidgets('is a page, not a dialog', (t) async {
    await t.pumpWidget(host(const ChangePasswordPage()));
    await t.pump();

    // A Scaffold with its own app bar, which is what makes room for the third
    // field and keeps the button clear of the keyboard.
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
  });

  testWidgets('asks for the new password twice', (t) async {
    await t.pumpWidget(host(const ChangePasswordPage()));
    await t.pump();

    // Three fields: current, new, and the confirmation the dialog had no room
    // for. Typing a password you cannot see, on the screen that replaces the
    // one you know, is how somebody locks themselves out.
    expect(find.byType(AppPasswordField), findsNWidgets(3));
    expect(find.text('Confirm New Password'), findsOneWidget);
  });

  testWidgets('a mistyped confirmation is caught here, not by the server',
      (t) async {
    await t.pumpWidget(host(const ChangePasswordPage()));
    await t.pump();

    await fill(t, current: 'OldPass1!', next: 'NewPass1!', confirm: 'NewPass2!');
    await submit(t);

    expect(find.text('*Passwords do not match'), findsOneWidget);
  });

  testWidgets('a weak new password is refused with the rule it broke',
      (t) async {
    await t.pumpWidget(host(const ChangePasswordPage()));
    await t.pump();

    await fill(t, current: 'OldPass1!', next: 'password', confirm: 'password');
    await submit(t);

    // The specific unmet rule, not "invalid password" — the server's answer
    // would have been the latter.
    expect(find.text('*Add an uppercase letter'), findsOneWidget);
  });

  testWidgets('the new password cannot be the current one', (t) async {
    await t.pumpWidget(host(const ChangePasswordPage()));
    await t.pump();

    await fill(t, current: 'OldPass1!', next: 'OldPass1!', confirm: 'OldPass1!');
    await submit(t);

    expect(find.text('*This is already your password'), findsOneWidget);
  });

  testWidgets('an old, weak current password is still accepted as typed',
      (t) async {
    await t.pumpWidget(host(const ChangePasswordPage()));
    await t.pump();

    // Accounts predate the strength rule. Holding the *current* password to it
    // would tell someone their own working password is invalid, on the one
    // screen that exists to let them replace it.
    await fill(t, current: 'oldpass', next: 'NewPass1!', confirm: 'NewPass1!');
    await t.pump();

    expect(find.text('*Enter your current password'), findsNothing);
    expect(find.textContaining('*Minimum'), findsNothing);
  });

  test('nothing opens it as a dialog any more', () {
    final source = File(
      'lib/features/settings/presentation/pages/account_security_page.dart',
    ).readAsStringSync();

    expect(source, contains('ChangePasswordPage()'));
    expect(
      source,
      isNot(contains('_ChangePasswordDialog')),
      reason: 'the dialog should be gone, not merely unreachable',
    );
  });
}
