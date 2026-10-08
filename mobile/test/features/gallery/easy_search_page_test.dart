import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
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

  group('the save-my-face row', () {
    const label = 'Save my face so I am found in future events';

    /// The label wraps to three lines at phone widths, so "level" means level
    /// with its **first** line — not with the centre of the block, which is a
    /// third of the way down a paragraph and nowhere near the box.
    void expectLevelWithFirstLine(WidgetTester tester) {
      final box = tester.getRect(find.byType(Checkbox));
      final text = tester.getRect(find.text(label));
      final line = AppTypography.sm * 1.4; // the label's line height

      expect(text.height, greaterThan(line * 1.5),
          reason: 'this label is expected to wrap — if it stopped wrapping, '
              'the first-line check below is no longer the interesting one');

      final firstLineCentre = text.top + line / 2;
      expect((box.center.dy - firstLineCentre).abs(), lessThan(1.0),
          reason: 'the checkbox and the first line of its label should share '
              'a centre, within a pixel');
    }

    testWidgets('the box is level with the first line of its label',
        (tester) async {
      // It was not. `CrossAxisAlignment.start` lines the box up with the top
      // of the text *block*, and the label's 1.4 line height puts a fifth of
      // an em of leading above the letters — so the words sat low against the
      // box. A 2px nudge on the text had been added to compensate, which
      // moved the words rather than the box, and by a guessed amount.
      await pumpPage(tester);
      expectLevelWithFirstLine(tester);
    });

    testWidgets('it stays level on a narrow phone', (tester) async {
      // The alignment is derived from the line height rather than hard-coded,
      // so it has to hold wherever the text wraps differently.
      await pumpPage(tester, size: const Size(320, 640));
      expectLevelWithFirstLine(tester);
    });
  });
}
