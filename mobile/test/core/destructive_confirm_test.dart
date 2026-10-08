import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_confirm_dialog.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The button that cannot be undone does not look like the one that can.
///
/// Deleting an account offered "Cancel" and "Delete" as two identical pieces
/// of text in the same colour, so the irreversible one was the easier of the
/// two to hit without reading. `showAppConfirmDialog` has had an
/// `isDestructive` flag the whole time — three screens had simply hand-rolled
/// their own `AlertDialog` with two plain `TextButton`s instead.
///
/// Guarded two ways: the dialog paints the confirm button red when asked, and
/// no screen hand-rolls a delete confirmation of its own. The second is the
/// one that matters — the first cannot fail while every caller goes through
/// the shared dialog, and a new screen that does not is exactly how this came
/// back.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        home: Scaffold(body: child),
      ),
    );

/// The fill `AppButtonVariant.destructive` paints — see app_button.dart.
const _destructiveRed = Color(0xFFB00020);

Future<void> openDialog(WidgetTester t, {required bool destructive}) async {
  await t.pumpWidget(host(Builder(
    builder: (context) => TextButton(
      onPressed: () => showAppConfirmDialog(
        context,
        title: 'Delete your account?',
        message: 'This cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: destructive,
      ),
      child: const Text('open'),
    ),
  )));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('the confirm button is red when the action is destructive',
      (t) async {
    await openDialog(t, destructive: true);

    final confirm = t.widget<AppButton>(
      find.widgetWithText(AppButton, 'Delete'),
    );
    expect(confirm.variant, AppButtonVariant.destructive);

    // Red on the screen, not merely labelled destructive in the tree: the
    // variant picks a fill, and this is the fill it picked.
    final button = t.widget<ElevatedButton>(
      find.descendant(
        of: find.widgetWithText(AppButton, 'Delete'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.style?.backgroundColor?.resolve({}), _destructiveRed);
  });

  testWidgets('and Cancel is not', (t) async {
    await openDialog(t, destructive: true);

    final cancel = t.widget<AppButton>(
      find.widgetWithText(AppButton, 'Cancel'),
    );
    expect(cancel.variant, AppButtonVariant.text);
  });

  testWidgets('an ordinary confirmation stays on the brand colour', (t) async {
    await openDialog(t, destructive: false);

    final confirm = t.widget<AppButton>(
      find.widgetWithText(AppButton, 'Delete'),
    );
    expect(confirm.variant, AppButtonVariant.primary);
  });

  test('no screen hand-rolls its own delete confirmation', () {
    // Asserted against the source because the failure is not a broken widget:
    // it is a dialog that renders perfectly with two identical buttons. A
    // bare `TextButton` labelled Delete/Remove/Log out inside an `AlertDialog`
    // is that dialog.
    final offenders = <String>[];
    final destructiveLabel = RegExp(
      r'''child:\s*const\s+Text\(\s*'(Delete|Remove|Log ?out|Sign out|Block|Leave)'\s*\)''',
    );

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      if (!source.contains('AlertDialog')) continue;
      if (destructiveLabel.hasMatch(source)) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'use showAppConfirmDialog(isDestructive: true) so the '
          'irreversible button is red',
    );
  });
}
