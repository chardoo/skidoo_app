import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:jperg_app/components/comments/comment_sheet_shell.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The sheet has to give the keyboard room out of its own height.
///
/// It used to keep its full [kCommentSheetFraction] and take the keyboard as
/// padding underneath, asking for `0.63 * screen + keyboard` — more than the
/// screen. A bottom-anchored box cannot grow downwards, so the excess went off
/// the top and swallowed the media band, leaving a sliver behind the status
/// bar. The photo was laid out correctly the whole time; the sheet was on top
/// of it.
///
/// The rule these pin: **the sheet's top edge does not move when the keyboard
/// opens.** That is what keeps the thing being discussed on screen while you
/// type about it, which is the entire point of the arrangement.
const screen = Size(390, 844);

Widget host({required double keyboard}) => ScreenUtilInit(
      designSize: screen,
      builder: (context, _) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: MediaQuery(
          data: MediaQueryData(
            size: screen,
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: CommentSheetShell(
              title: 'richwedding',
              subtitle: 'by Omg photos',
              child: SizedBox.expand(key: Key('list')),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher.views.first;
    view.physicalSize = screen;
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Where the sheet's top edge sits, which is the line the media band ends on.
  Future<double> sheetTop(WidgetTester tester, double keyboard) async {
    await tester.pumpWidget(host(keyboard: keyboard));
    // Past the 180ms keyboard easing.
    await tester.pump(const Duration(milliseconds: 400));
    return tester.getRect(find.byType(CommentSheetShell)).top;
  }

  testWidgets('with no keyboard the sheet leaves the designed band',
      (tester) async {
    final top = await sheetTop(tester, 0);

    expect(top, closeTo(screen.height * (1 - kCommentSheetFraction), 1));
  });

  testWidgets('the keyboard does not push the sheet over the media',
      (tester) async {
    // A typical iPhone keyboard: a little over a third of the screen.
    const keyboard = 336.0;

    final top = await sheetTop(tester, keyboard);

    // The same line as with no keyboard — the band above is untouched.
    expect(top, closeTo(screen.height * (1 - kCommentSheetFraction), 1));
    // And emphatically not shoved off the top, which is what the bug looked
    // like: a band squeezed down to the status bar.
    expect(top, greaterThan(100));
  });

  testWidgets('the band survives every keyboard height', (tester) async {
    final band = screen.height * (1 - kCommentSheetFraction);

    for (final keyboard in [0.0, 120.0, 260.0, 336.0]) {
      expect(
        await sheetTop(tester, keyboard),
        closeTo(band, 1),
        reason: 'keyboard $keyboard moved the sheet off its line',
      );
    }
  });

  testWidgets('a very tall keyboard is floored rather than collapsing the sheet',
      (tester) async {
    // A predictive bar and an emoji row on a short device. Subtracting this
    // outright would leave 72 — not enough to type in — so the sheet stops
    // shrinking and takes the band down with it instead. A cramped band beats
    // a sheet you cannot use.
    const keyboard = 460.0;
    final top = await sheetTop(tester, keyboard);

    // Derived from the top edge rather than measured off the widget: the shell
    // rect includes the keyboard padding it holds, so its height is the sheet
    // plus the keyboard, not the sheet.
    expect(screen.height - keyboard - top, closeTo(140, 1));
    expect(top, lessThan(screen.height * (1 - kCommentSheetFraction)));
    // Still a band, though — the media never goes away entirely.
    expect(top, greaterThan(200));
  });
}
