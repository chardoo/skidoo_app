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
  /// The default test view is 800x600 — wider than any phone and shorter than
  /// all of them. This screen is built for the design size it declares below,
  /// and a 3-column grid in an 800px-wide view gives tiles 250px tall, which
  /// is a shape no device produces. Pinned so a layout assertion here means
  /// something about a real phone.
  Future<void> pumpPage(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme:
                ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
            home: const EasySearchPage(),
          ),
        ),
      );
  }

  testWidgets('it fits a short phone without overflowing', (tester) async {
    // A 360x640 Android, the smallest ordinary screen: the explainer, the
    // code row, the keep-my-face box, the button and the legal links are all
    // fixed height, and only the selfie grid can give way.
    await pumpPage(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
  });

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
