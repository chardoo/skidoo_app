import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_ready_page.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/creator_steps.dart';

/// The chrome of becoming a creator.
///
/// The step row and the closing screen are the two places the flow tells
/// somebody where they are and what just happened, and both are pure widgets —
/// so they can be checked without a backend or a navigator.
Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('CreatorSteps', () {
    testWidgets('names both steps and numbers the one not yet reached',
        (tester) async {
      await tester.pumpWidget(_host(const CreatorSteps(current: 0)));
      await tester.pumpAndSettle();

      expect(find.text('Profile Info'), findsOneWidget);
      expect(find.text('Verification'), findsOneWidget);
      // Step two is still ahead, so it shows its number.
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('ticks a step once it is behind you', (tester) async {
      await tester.pumpWidget(_host(const CreatorSteps(current: 1)));
      await tester.pumpAndSettle();

      // One tick for step one, and step two no longer shows a "1" beside it.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('reads as one announcement, not four fragments',
        (tester) async {
      // Split across the circles and captions it reads out as "1", "Profile
      // Info", "2", "Verification", which says nothing about progress.
      await tester.pumpWidget(_host(const CreatorSteps(current: 1)));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Step 2 of 2: Verification'),
        findsOneWidget,
      );
    });
  });

  group('CreatorReadyPage', () {
    testWidgets('greets them by name', (tester) async {
      await tester.pumpWidget(_host(const CreatorReadyPage(name: 'Kwame')));
      await tester.pumpAndSettle();

      expect(find.text("You're all set, Kwame!"), findsOneWidget);
      expect(find.text('Upload photos'), findsOneWidget);
      expect(find.text("I'll do this later"), findsOneWidget);
    });

    testWidgets('drops the name rather than greeting a blank', (tester) async {
      await tester.pumpWidget(_host(const CreatorReadyPage(name: '')));
      await tester.pumpAndSettle();

      expect(find.text("You're all set!"), findsOneWidget);
    });

    testWidgets('does not claim they are verified', (tester) async {
      // The ID is queued for review and the badge comes later. Saying
      // "verified" here would be the screen making a promise an admin has not
      // made yet.
      await tester.pumpWidget(_host(const CreatorReadyPage(name: 'Kwame')));
      await tester.pumpAndSettle();

      expect(find.textContaining('verified'), findsNothing);
      expect(find.textContaining('Verified'), findsNothing);
    });

    test('takes the first name only', () {
      // "You're all set, Kwame Mensah!" reads like a letter from a bank.
      expect(CreatorReadyPage.firstNameOf('Kwame Mensah'), 'Kwame');
      expect(CreatorReadyPage.firstNameOf('  Ama   Serwaa '), 'Ama');
      expect(CreatorReadyPage.firstNameOf(''), '');
      expect(CreatorReadyPage.firstNameOf('   '), '');
    });
  });
}
