import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_phone_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/validators/validators.dart';

/// Too long was flagged; too short was not.
///
/// The field holds the full E.164 number for the form to submit —
/// `+233241234567` — and it was handing *that* to the validator, which is
/// documented as checking the national digits. The dial code paid for most
/// of the minimum on its own: `+233` is four characters of the six that were
/// required, so two typed digits passed while a long number still tripped
/// the ceiling. Exactly the asymmetry that was reported.
Widget host(TextEditingController controller) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: AppPhoneField(
            controller: controller,
            label: 'Phone number',
            validator: Validators.nationalPhoneValidator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ),
      ),
    );

Future<void> type(WidgetTester t, String digits) async {
  await t.enterText(find.byType(TextField), digits);
  await t.pump();
}

void main() {
  late TextEditingController controller;

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
    controller = TextEditingController();
  });

  tearDown(() => controller.dispose());

  testWidgets('a short number is flagged', (t) async {
    await t.pumpWidget(host(controller));

    await type(t, '24');

    expect(find.textContaining('short'), findsOneWidget);
  });

  testWidgets('and so is a slightly-less-short one', (t) async {
    // Six national digits still is not a phone number anywhere.
    await t.pumpWidget(host(controller));

    await type(t, '241234');

    expect(find.textContaining('short'), findsOneWidget);
  });

  testWidgets('a long number is flagged, as it always was', (t) async {
    await t.pumpWidget(host(controller));

    await type(t, '12345678901234');

    expect(find.textContaining('long'), findsOneWidget);
  });

  testWidgets('a real number is accepted', (t) async {
    await t.pumpWidget(host(controller));

    await type(t, '241234567');

    expect(find.textContaining('short'), findsNothing);
    expect(find.textContaining('long'), findsNothing);
  });

  testWidgets('the form still submits the full E.164 number', (t) async {
    // The fix changes what the *validator* sees, not what the form sends.
    await t.pumpWidget(host(controller));

    await type(t, '0241234567');

    expect(controller.text, '+233241234567',
        reason: 'dial code prefixed, trunk zero dropped');
  });

  testWidgets('the dial code does not pay for the minimum', (t) async {
    // The regression this is really here for. `+233` plus four digits is
    // seven digits in total — enough to clear the floor if the full number
    // is ever measured again, while only four were actually typed.
    await t.pumpWidget(host(controller));

    await type(t, '2412');

    expect(controller.text, '+2332412', reason: 'seven digits in total');
    expect(find.textContaining('short'), findsOneWidget,
        reason: 'four typed digits is short, whatever the dial code adds');
  });
}
