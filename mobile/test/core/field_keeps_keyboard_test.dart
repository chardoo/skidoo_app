import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_phone_field.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The keyboard has to stay up while somebody is typing.
///
/// Both shared inputs used to return a different *shape* depending on whether
/// the field was in error — the bare box when it was fine, a Column carrying
/// the box and the message when it was not. Flutter matches a rebuilt child by
/// runtime type, so every flip of that flag threw away the element holding the
/// `EditableText` and built a new one. A new EditableText means a new
/// connection to the platform text input, and the old one closing under it: on
/// a device that is the keyboard dropping.
///
/// The signup form validates as you type (`onUserInteraction`), so the flag
/// flips mid-word — the first character of a password makes it invalid, and the
/// eighth makes it valid again. Two dropped keyboards per field, which is
/// exactly how it was reported.
///
/// These assert element identity rather than anything about the keyboard,
/// because that is the thing that actually has to hold: the test harness has no
/// real keyboard to drop.
void main() {
  Widget formWith(Widget field) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData(extensions: const [AppThemeExtension.light]),
          home: Scaffold(
            body: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: field,
            ),
          ),
        ),
      );

  /// The live [EditableText] state — the object that owns the text input
  /// connection. If this is not the same instance before and after, the
  /// connection was torn down and rebuilt, and the keyboard went with it.
  EditableTextState editable(WidgetTester t) =>
      t.state<EditableTextState>(find.byType(EditableText));

  testWidgets('AppTextField survives a value going invalid, then valid',
      (t) async {
    await t.pumpWidget(formWith(AppTextField(
      controller: TextEditingController(),
      label: 'Password',
      // The shape of the real signup rule: short is wrong, long is fine.
      validator: (v) => (v ?? '').length < 8 ? '*Minimum 8 characters' : null,
    )));

    final before = editable(t);

    // First keystroke — the field is now in error.
    await t.enterText(find.byType(TextField), 'a');
    await t.pumpAndSettle();
    expect(find.text('*Minimum 8 characters'), findsOneWidget);
    expect(editable(t), same(before),
        reason: 'the message appearing must not rebuild the field');

    // Eighth keystroke — the error goes away again.
    await t.enterText(find.byType(TextField), 'abcdefgh');
    await t.pumpAndSettle();
    expect(find.text('*Minimum 8 characters'), findsNothing);
    expect(editable(t), same(before),
        reason: 'the message leaving must not rebuild it either');
  });

  testWidgets('AppPasswordField survives it too', (t) async {
    await t.pumpWidget(formWith(AppPasswordField(
      controller: TextEditingController(),
      label: 'New Password',
      validator: (v) => (v ?? '').length < 8 ? '*Minimum 8 characters' : null,
    )));

    final before = editable(t);

    await t.enterText(find.byType(TextField), 'a');
    await t.pumpAndSettle();
    expect(editable(t), same(before));

    await t.enterText(find.byType(TextField), 'abcdefgh');
    await t.pumpAndSettle();
    expect(editable(t), same(before));
  });

  testWidgets('AppPhoneField survives it too', (t) async {
    final controller = TextEditingController();
    await t.pumpWidget(formWith(AppPhoneField(
      controller: controller,
      label: 'Phone Number',
      validator: (v) =>
          (v ?? '').length < 13 ? '*Enter a valid phone number' : null,
    )));

    final before = editable(t);

    await t.enterText(find.byType(TextField), '2');
    await t.pumpAndSettle();
    expect(find.text('*Enter a valid phone number'), findsOneWidget);
    expect(editable(t), same(before));

    await t.enterText(find.byType(TextField), '241234567');
    await t.pumpAndSettle();
    expect(find.text('*Enter a valid phone number'), findsNothing);
    expect(editable(t), same(before));
  });

  testWidgets('a banner coming and going above the fields leaves them alone',
      (t) async {
    // The other half of the signup screen's shape: a failed submit puts an
    // error banner above the form, and the first keystroke afterwards clears
    // it. That inserts and removes two children from the column the fields
    // live in, which is the other way a field can be rebuilt out from under
    // somebody who is typing.
    final controller = TextEditingController();
    var showBanner = true;

    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create account'),
                const SizedBox(height: 8),
                if (showBanner) ...[
                  const Text('That email is already in use'),
                  const SizedBox(height: 8),
                ],
                AppTextField(
                  controller: controller,
                  label: 'Email',
                  onChanged: (_) => setState(() => showBanner = false),
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    final before = editable(t);
    expect(find.text('That email is already in use'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'j');
    await t.pumpAndSettle();

    expect(find.text('That email is already in use'), findsNothing);
    expect(editable(t), same(before),
        reason: 'clearing the banner must not rebuild the field below it');
  });

  testWidgets('and the focus node keeps its focus across the flip', (t) async {
    // The node is held by the State and so survives on its own; this is here
    // because "still focused" is what the reporter would check, and a future
    // rewrite could keep element identity while losing focus some other way.
    await t.pumpWidget(formWith(AppTextField(
      controller: TextEditingController(),
      label: 'Password',
      validator: (v) => (v ?? '').length < 8 ? '*Minimum 8 characters' : null,
    )));

    await t.tap(find.byType(TextField));
    await t.pumpAndSettle();
    expect(editable(t).widget.focusNode.hasFocus, isTrue);

    await t.enterText(find.byType(TextField), 'a');
    await t.pumpAndSettle();
    expect(editable(t).widget.focusNode.hasFocus, isTrue,
        reason: 'typing must not hand focus back');
  });
}
