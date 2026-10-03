import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/easy_search_page.dart';

/// Both halves are required, and the button says which one is missing.
///
/// A disabled button with no explanation is the failure mode here: the person
/// has taken a selfie, the thing still will not go, and nothing on screen says
/// the code is what is wanted.
void main() {
  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme:
                ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
            home: const EasySearchPage(),
          ),
        ),
      );

  AppButton submitButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.byType(AppButton));

  testWidgets('it will not start with nothing', (tester) async {
    await pumpPage(tester);

    final button = submitButton(tester);
    expect(button.onPressed, isNull);
    expect(button.label, 'Take a selfie to continue');
  });

  testWidgets('it asks for the selfie before the code', (tester) async {
    // The selfie is the slower, more personal step, and the one the screen is
    // mostly about — so an empty form names that rather than the code.
    await pumpPage(tester);

    expect(submitButton(tester).label, contains('selfie'));
  });

  testWidgets('the album is offered as its own row', (tester) async {
    await pumpPage(tester);

    expect(find.text('Enter or scan the event code'), findsOneWidget);
  });

  testWidgets('the privacy promise is on the screen that collects the faces',
      (tester) async {
    // Not only on the button that led here: this is the screen where the
    // selfies are actually taken, and the claim belongs where the cost is.
    await pumpPage(tester);

    expect(find.textContaining('never saved'), findsOneWidget);
  });

  testWidgets('it offers at most four selfies', (tester) async {
    // The face service's own ceiling on reference photos — a fifth would be
    // refused by the server.
    await pumpPage(tester);

    expect(find.text('0 / 4'), findsOneWidget);
  });
}
