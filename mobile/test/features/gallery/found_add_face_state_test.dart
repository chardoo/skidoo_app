/// The two empty Found tabs, and which words belong on which.
///
/// They were one screen. Somebody who had never added a face was told
/// "Scanning for your face — we haven't matched you to any photo yet. We'll
/// notify you once we do", and every clause of that was false for them:
/// nothing was scanning, nothing could be matched, and no notification was
/// ever coming. It described work that was not happening and gave them nothing
/// to do about it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_add_face_state.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_scanning_state.dart';

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('with no face on file', () {
    testWidgets('it asks for one, and offers the way to give it',
        (tester) async {
      await tester.pumpWidget(host(FoundAddFaceState(onTakeSelfie: () {})));
      await tester.pump();

      expect(find.text('Add your face to get found'), findsOneWidget);
      expect(
        find.text(
          'Upload a selfie so we can match you in photos from events you '
          'attend.',
        ),
        findsOneWidget,
      );
      expect(find.text('Take a selfie'), findsOneWidget);
    });

    testWidgets('it claims no scan is running', (tester) async {
      await tester.pumpWidget(host(FoundAddFaceState(onTakeSelfie: () {})));
      await tester.pump();

      // The sentences that belong to the other screen, and would be lies here.
      expect(find.textContaining('Scanning'), findsNothing);
      expect(find.textContaining("haven't matched you"), findsNothing);
      expect(find.textContaining('notify you'), findsNothing);
    });

    testWidgets('the button is about half the width, not the whole of it',
        (tester) async {
      // It shipped wall-to-wall. The design draws a pill across roughly half
      // the frame, and a button spanning the screen reads as the only thing
      // left to do on a tab somebody may just be passing through.
      //
      // The *declared* size, not the rendered one: flutter_test substitutes a
      // font whose every glyph is a square of the font size, so "Take a
      // selfie" measures 185pt here against roughly half that on a device.
      // Asserting what it renders to would be asserting the test font.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(FoundAddFaceState(onTakeSelfie: () {})));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final size = button.style!.minimumSize!.resolve({})!;
      expect(size.width, kTakeSelfieButtonWidth);
      expect(size.height, 48);
      expect(kTakeSelfieButtonWidth / 390, lessThan(0.6),
          reason: 'half the frame, not the whole of it');
    });

    testWidgets('nothing stretches it to the full width', (tester) async {
      // The shape the bug had: a SizedBox(width: double.infinity) around it.
      await tester.pumpWidget(host(FoundAddFaceState(onTakeSelfie: () {})));
      await tester.pump();

      final boxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((b) => b.width == double.infinity);
      expect(boxes, isEmpty);
    });

    testWidgets('the button is what opens the flow', (tester) async {
      // What it opens is the code sheet, not the camera — a selfie only means
      // something once the album is known. Asserted at the call site rather
      // than here; this pins that the tap is wired at all.
      var tapped = false;
      await tester.pumpWidget(
        host(FoundAddFaceState(onTakeSelfie: () => tapped = true)),
      );
      await tester.pump();

      await tester.tap(find.text('Take a selfie'));
      expect(tapped, isTrue);
    });
  });

  group('with a face on file and no matches', () {
    testWidgets('it says the system is working, and asks for nothing',
        (tester) async {
      await tester.pumpWidget(host(const FoundScanningState()));
      await tester.pump();

      expect(find.text('Scanning for your face'), findsOneWidget);
      // Nothing is being asked of them, so there is no primary button.
      expect(find.text('Take a selfie'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('the code is offered as the escape hatch', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(FoundScanningState(onEnterCode: () => tapped = true)),
      );
      await tester.pump();

      await tester.tap(find.text('Have a code from a photographer?'));
      expect(tapped, isTrue);
    });
  });

  group('the screens stay distinct', () {
    const dir = 'lib/features/gallery/presentation/found/widgets';

    test('the scanning screen never claims to be scanning for a missing face',
        () {
      // Source-level, because the failure being guarded against is somebody
      // folding these back into one widget with a conditional string — which
      // is the shape the bug had.
      final scanning =
          File('$dir/found_scanning_state.dart').readAsStringSync();
      expect(scanning, isNot(contains('Add your face to get found')));
      expect(scanning, isNot(contains('Take a selfie')));
    });

    test('the face panel makes no promise about scanning or notifying', () {
      final addFace = File('$dir/found_add_face_state.dart').readAsStringSync();
      // Comments explain why those sentences are wrong here, so only the
      // drawn strings are checked.
      final drawn = addFace
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//') &&
              !line.trimLeft().startsWith('///'))
          .join('\n');
      expect(drawn, isNot(contains('Scanning for your face')));
      expect(drawn, isNot(contains('notify you')));
    });

    test('the rule that picks between them is the one in found_access', () {
      final feed = File(
        'lib/features/gallery/presentation/found/found_feed.dart',
      ).readAsStringSync();
      expect(feed, contains('shouldOfferFacePanel'));
      expect(feed, contains('FoundAddFaceState'));
      // The sheet is summoned by the button now, not by the screen appearing.
      expect(feed, isNot(contains('_promptForCodeIfNothingToShow')));
    });
  });
}
