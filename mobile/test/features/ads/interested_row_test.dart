import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/presentation/widgets/interested_row.dart';

/// The row fitting the card it sits on.
///
/// It did not: three fixed-width avatars beside a label that could not shrink
/// overflowed a narrow request card by 12 px, and Flutter striped the corner.
///
/// The two halves are not equally worth keeping — "4 interested" is the
/// information and the faces are decoration on top of it — so the faces are
/// what give way. These pin that order, because the obvious fix (truncating
/// the label to "4 inter…" beside a full set of avatars) loses the wrong half.

RequestInterest _person(String id) => RequestInterest(id: id, name: 'Person $id');

Widget host(double width, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
        ),
        home: Scaffold(
          body: Center(child: SizedBox(width: width, child: child)),
        ),
      ),
    );

Widget rowWith(int count) => InterestedRow(
      interested: [for (var i = 0; i < count; i++) _person('$i')],
      count: count,
      ext: AppThemeExtension.dark,
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

  group('fitting the space it is given', () {
    for (final width in <double>[94.6, 120, 160, 200, 300]) {
      testWidgets('does not overflow at $width px', (tester) async {
        await tester.pumpWidget(host(width, rowWith(3)));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'the row overflowed at $width px');
      });
    }

    testWidgets('the count survives even when no face does', (tester) async {
      // The whole point of the ordering. At a width this tight every avatar is
      // dropped, and what remains is the thing worth reading.
      await tester.pumpWidget(host(70, rowWith(3)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('interested'), findsOneWidget);
    });

    testWidgets('a wide card still shows the full stack', (tester) async {
      // The shrinking must not be permanent — a card with room gets the design.
      await tester.pumpWidget(host(300, rowWith(3)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Positioned), findsNWidgets(3));
    });

    testWidgets('a four-figure count does not push it over', (tester) async {
      // The label is measured rather than assumed, so a longer count reserves
      // more room and drops another face instead of overflowing.
      await tester.pumpWidget(host(120, InterestedRow(
        interested: [for (var i = 0; i < 3; i++) _person('$i')],
        count: 1200,
        ext: AppThemeExtension.dark,
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('nobody interested draws nothing at all', (tester) async {
    await tester.pumpWidget(host(300, InterestedRow(
      interested: const [],
      count: 0,
      ext: AppThemeExtension.dark,
    )));
    await tester.pump();

    expect(find.textContaining('interested'), findsNothing);
  });
}
