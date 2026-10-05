import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/settings/presentation/personalisation_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the sheet says, and what both answers do.
///
/// The copy is the whole change. The old ask — "Share Usage Data / Help us
/// improve by sharing anonymized analytics", filed under "Diagnostic
/// analytics" — got 1 yes out of 228 accounts. It described a benefit to us
/// and never mentioned the feed.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Future<bool> Function() onAccept) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    return tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: Scaffold(
            body: PersonalisationSheet(onAccept: onAccept),
          ),
        ),
      ),
    );
  }

  testWidgets('it says what it does, in the words the benefit is in',
      (tester) async {
    await pump(tester, () async => true);

    expect(find.text('Personalise my feed'), findsWidgets);
    // The thing the old copy never said: this is about the feed.
    expect(find.textContaining('what to show you next'), findsOneWidget);
    // And the thing people actually want to know.
    expect(find.textContaining('never shared'), findsOneWidget);
    expect(find.textContaining('never used to identify you'), findsOneWidget);
  });

  testWidgets('it never calls itself analytics', (tester) async {
    await pump(tester, () async => true);
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ')
        .toLowerCase();

    expect(text, isNot(contains('analytics')));
    expect(text, isNot(contains('diagnostic')));
    expect(text, isNot(contains('help us improve')));
  });

  testWidgets('it says where to change your mind', (tester) async {
    await pump(tester, () async => true);
    expect(find.textContaining('Settings'), findsOneWidget);
  });

  testWidgets('declining is as easy to reach as accepting', (tester) async {
    // A "no" dressed as a link is a dark pattern, and the honest version is
    // what makes the "yes" worth having.
    await pump(tester, () async => true);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('accepting turns the setting on', (tester) async {
    var called = false;
    await pump(tester, () async {
      called = true;
      return true;
    });

    await tester.tap(find.widgetWithText(ElevatedButton, 'Personalise my feed'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });

  testWidgets('a failure keeps the sheet open and says so', (tester) async {
    // Closing would leave somebody believing they had turned something on
    // that is still off.
    await pump(tester, () async => false);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Personalise my feed'));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not save'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });
}
