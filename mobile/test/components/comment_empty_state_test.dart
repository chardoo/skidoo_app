import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_sheet_shell.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The empty state has to fit the sheet it is in.
///
/// It overflowed by 51 pixels in the ordinary case, not an exotic one: raising
/// the keyboard to write the first comment leaves this about 60 px of room and
/// the full arrangement wants 113. So the state that says "be the first to say
/// something" painted a black-and-yellow overflow bar over itself at exactly
/// the moment somebody was being invited to type.
Widget host(double height) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              height: height,
              child: const CommentEmptyState(ext: AppThemeExtension.dark),
            ),
          ),
        ),
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

  testWidgets('fits the sheet a keyboard has squeezed', (t) async {
    // 63.7 is the height from the report.
    await t.pumpWidget(host(63.7));
    await t.pump();

    expect(t.takeException(), isNull);
  });

  testWidgets('and anything narrower still', (t) async {
    await t.pumpWidget(host(40));
    await t.pump();

    expect(t.takeException(), isNull);
  });

  testWidgets('the sentence survives; the decoration is what goes', (t) async {
    await t.pumpWidget(host(63.7));
    await t.pump();

    // The icon is decoration. The words are the message, so they stay.
    expect(find.byType(Icon), findsNothing);
    expect(find.text('No comments yet'), findsOneWidget);
    expect(find.text('Be the first to say something'), findsOneWidget);
  });

  testWidgets('below two lines, the invitation goes and the heading stands',
      (t) async {
    await t.pumpWidget(host(40));
    await t.pump();

    expect(find.text('No comments yet'), findsOneWidget);
    expect(find.text('Be the first to say something'), findsNothing);
  });

  testWidgets('a sheet with room shows all of it', (t) async {
    await t.pumpWidget(host(400));
    await t.pump();

    expect(find.byType(Icon), findsOneWidget);
    expect(find.text('No comments yet'), findsOneWidget);
    expect(find.text('Be the first to say something'), findsOneWidget);
  });
}
