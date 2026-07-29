import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/common/widgets/app_phone_field.dart';
import 'package:skidoo_app/core/common/widgets/app_text_field.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Field height is easy to inflate by accident — the border lives on an
/// AnimatedContainer rather than on InputDecorator, so a floating `label`
/// stacks an extra row on top of `contentPadding` and the field grows twice as
/// fast as the number you edited. These pin the rendered heights that the
/// signup/onboarding forms actually show.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('labelled field (signup/onboarding) stays near Material\'s 56dp',
      (t) async {
    await t.pumpWidget(host(AppTextField(
      controller: TextEditingController(),
      label: 'Email address',
      hint: 'e.g. jane@example.com',
      prefixIcon: Icons.mail_outline_rounded,
    )));
    await t.pumpAndSettle();
    // Was 75.5 with vertical: 18.
    expect(t.getSize(find.byType(AppTextField)).height, closeTo(63.5, 1.5));
  });

  testWidgets('unlabelled field keeps the 48dp touch target', (t) async {
    await t.pumpWidget(host(AppTextField(
      controller: TextEditingController(),
      hint: 'Search',
    )));
    await t.pumpAndSettle();
    final h = t.getSize(find.byType(AppTextField)).height;
    expect(h, closeTo(50, 1.5));
    expect(h, greaterThanOrEqualTo(48));
  });

  testWidgets('phone field matches the text fields it sits beside', (t) async {
    await t.pumpWidget(host(AppPhoneField(
      controller: TextEditingController(),
      label: 'Phone number',
    )));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(AppPhoneField)).height,
        lessThanOrEqualTo(66));
  });
}
