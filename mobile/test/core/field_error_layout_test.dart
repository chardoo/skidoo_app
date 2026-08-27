import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_phone_field.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Where a validation message is allowed to appear.
///
/// The fill and border of both shared inputs are drawn by an AnimatedContainer
/// wrapping the field, not by InputDecorator — so anything InputDecorator drew
/// landed *inside* that box. The error text was squeezed up with
/// `errorStyle: height: 0.1` until it sat on the bottom border and struck
/// through it, which is what shipped: a red sentence with a line through it,
/// overlapping the edge of the field it belonged to.
///
/// These tests are geometric on purpose. "The message is present" was true of
/// the broken build too; what was wrong was where it was drawn.

const _long =
    '*Please choose a password that does not contain your name or email address';

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: child,
          ),
        ),
      ),
    );

Widget formWith(Widget field, GlobalKey<FormState> key) => host(
      Form(
        key: key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: field,
      ),
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('AppTextField', () {
    testWidgets('the message sits below the box, never across its border',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppTextField(
          controller: controller,
          label: 'New Password',
          validator: (v) => (v == null || v.length < 8)
              ? '*Minimum 8 characters'
              : null,
        ),
        GlobalKey<FormState>(),
      ));

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      final box = tester.getRect(find.byType(AnimatedContainer));
      final message = tester.getRect(find.text('*Minimum 8 characters'));

      expect(message.top, greaterThanOrEqualTo(box.bottom),
          reason: 'the message must clear the field border, not overlap it');
    });

    testWidgets('the message keeps its full line height', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppTextField(
          controller: controller,
          validator: (_) => '*Minimum 8 characters',
        ),
        GlobalKey<FormState>(),
      ));

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      // The old `height: 0.1` collapsed this to roughly one pixel, which is
      // how the text ended up drawn over the border in the first place.
      final message = tester.getRect(find.text('*Minimum 8 characters'));
      expect(message.height, greaterThan(10));
    });

    testWidgets('a long message wraps instead of being cut off',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppTextField(controller: controller, validator: (_) => _long),
        GlobalKey<FormState>(),
      ));

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      final rendered = tester.renderObject<RenderParagraph>(find.text(_long));
      expect(rendered.didExceedMaxLines, isFalse,
          reason: 'errorMaxLines: 1 truncated the half that explains the fix');
      final message = tester.getRect(find.text(_long));
      expect(message.height, greaterThan(20), reason: 'expected >1 line');
    });

    testWidgets('validation still runs through the enclosing form',
        (tester) async {
      final key = GlobalKey<FormState>();
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppTextField(
          controller: controller,
          validator: (v) => (v ?? '').isEmpty ? '*Required' : null,
        ),
        key,
      ));

      // Rewritten around FormField rather than TextFormField — Form.validate()
      // has to keep seeing it.
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('*Required'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'something');
      await tester.pumpAndSettle();
      expect(key.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('*Required'), findsNothing);
    });

    testWidgets('text set on the controller from outside re-validates',
        (tester) async {
      final key = GlobalKey<FormState>();
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppTextField(
          controller: controller,
          validator: (v) => (v ?? '').isEmpty ? '*Required' : null,
        ),
        key,
      ));

      expect(key.currentState!.validate(), isFalse);
      await tester.pump();

      // Never passes through onChanged — the field would otherwise go on
      // validating a value the user can no longer see.
      controller.text = 'filled in';
      await tester.pumpAndSettle();

      expect(key.currentState!.validate(), isTrue);
    });

    testWidgets('a bare (unfilled) field reports errors too', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppTextField(
          controller: controller,
          filled: false,
          validator: (_) => '*Required',
        ),
        GlobalKey<FormState>(),
      ));

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      expect(find.text('*Required'), findsOneWidget);
    });
  });

  group('AppPasswordField', () {
    testWidgets('the message clears the box, as on the reset screen',
        (tester) async {
      // The screen this was reported from: two stacked password fields, both
      // in error, the first message struck through the first field's border.
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppPasswordField(
          controller: controller,
          label: 'New Password',
          validator: (_) => '*Minimum 8 characters',
        ),
        GlobalKey<FormState>(),
      ));

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      final box = tester.getRect(find.byType(AnimatedContainer));
      final message = tester.getRect(find.text('*Minimum 8 characters'));
      expect(message.top, greaterThanOrEqualTo(box.bottom));
    });
  });

  group('AppPhoneField', () {
    testWidgets('the message sits below the box', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppPhoneField(
          controller: controller,
          label: 'Phone Number',
          validator: (_) => '*Enter a valid phone number',
        ),
        GlobalKey<FormState>(),
      ));

      await tester.enterText(find.byType(TextField), '2');
      await tester.pumpAndSettle();

      final box = tester.getRect(find.byType(AnimatedContainer));
      final message = tester.getRect(find.text('*Enter a valid phone number'));
      expect(message.top, greaterThanOrEqualTo(box.bottom));
    });

    testWidgets('the validator sees the full E.164 number, not the digits typed',
        (tester) async {
      String? seen;
      final controller = TextEditingController();
      await tester.pumpWidget(formWith(
        AppPhoneField(
          controller: controller,
          label: 'Phone Number',
          validator: (v) {
            seen = v;
            return null;
          },
        ),
        GlobalKey<FormState>(),
      ));

      await tester.enterText(find.byType(TextField), '241234567');
      await tester.pumpAndSettle();

      expect(seen, controller.text);
      expect(seen, startsWith('+'));
    });
  });
}
