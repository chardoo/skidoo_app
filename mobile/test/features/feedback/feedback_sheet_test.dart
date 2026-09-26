import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/feedback/data/feedback_api.dart';
import 'package:jperg_app/features/feedback/presentation/feedback_sheet.dart';

/// The prompt itself: stars, then the sentence that is the actual point.
///
/// The score is a number on a dashboard. What somebody types after it is the
/// only part anybody can act on — so most of these are about the second step
/// getting asked, getting asked the *right* question, and surviving a send
/// that fails.
class _Recorder implements FeedbackApi {
  _Recorder({this.succeeds = true});

  final bool succeeds;
  final sent = <Map<String, Object?>>[];

  @override
  Future<bool> submit({
    required FeedbackKind kind,
    int? rating,
    String? message,
    String? appVersion,
    String? platform,
  }) async {
    sent.add({'kind': kind.wire, 'rating': rating, 'message': message});
    return succeeds;
  }

  @override
  Future<DateTime?> lastSubmitted(FeedbackKind kind) async => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: Scaffold(body: child),
        ),
      );

  Future<void> open(WidgetTester t, _Recorder api,
      {bool startOnFeature = false}) async {
    await t.pumpWidget(host(FeedbackSheet(api: api, startOnFeature: startOnFeature)));
    await t.pump();
  }

  group('the two steps', () {
    testWidgets('it opens on the stars', (t) async {
      await open(t, _Recorder());

      expect(find.text('How are you finding Jperg?'), findsOneWidget);
    });

    testWidgets('a happy score is asked what to build', (t) async {
      await open(t, _Recorder());

      await t.tap(find.bySemanticsLabel('5 stars'));
      await t.pumpAndSettle();

      expect(find.text('What should we build next?'), findsOneWidget);
    });

    testWidgets('an unhappy score is asked what went wrong', (t) async {
      // Asking a disappointed person for feature ideas reads as not having
      // listened to the thing they just told you.
      await open(t, _Recorder());

      await t.tap(find.bySemanticsLabel('2 stars'));
      await t.pumpAndSettle();

      expect(find.text('What went wrong?'), findsOneWidget);
    });

    testWidgets('Settings skips the stars entirely', (t) async {
      // Somebody who went looking for "Suggest a feature" has already decided
      // what they want to say; making them rate the app first is a toll.
      await open(t, _Recorder(), startOnFeature: true);

      expect(find.text('What should we build next?'), findsOneWidget);
      expect(find.text('How are you finding Jperg?'), findsNothing);
    });
  });

  group('what gets sent', () {
    testWidgets('a score alone is worth having', (t) async {
      final api = _Recorder();
      await open(t, api);

      await t.tap(find.bySemanticsLabel('5 stars'));
      await t.pumpAndSettle();
      await t.tap(find.text('Skip'));
      await t.pumpAndSettle();

      expect(api.sent, [
        {'kind': 'rating', 'rating': 5, 'message': null}
      ]);
    });

    testWidgets('a happy score and an idea are two separate things', (t) async {
      // The rating is a verdict and the idea is a proposal — one row each, so
      // the feature request lands in the triage queue rather than as a comment
      // attached to a five.
      final api = _Recorder();
      await open(t, api);

      await t.tap(find.bySemanticsLabel('5 stars'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Album downloads');
      await t.tap(find.text('Send'));
      await t.pumpAndSettle();

      expect(api.sent.length, 2);
      expect(api.sent[0]['kind'], 'rating');
      expect(api.sent[1], {
        'kind': 'feature_request',
        'rating': null,
        'message': 'Album downloads',
      });
    });

    testWidgets('an unhappy score keeps its explanation with it', (t) async {
      // "Uploads fail" is not a thing to build — it belongs on the rating, not
      // in the feature queue.
      final api = _Recorder();
      await open(t, api);

      await t.tap(find.bySemanticsLabel('2 stars'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Uploads fail');
      await t.tap(find.text('Send'));
      await t.pumpAndSettle();

      expect(api.sent, [
        {'kind': 'rating', 'rating': 2, 'message': 'Uploads fail'}
      ]);
    });

    testWidgets('Settings sends only a feature request', (t) async {
      final api = _Recorder();
      await open(t, api, startOnFeature: true);

      await t.enterText(find.byType(TextField), 'Album downloads');
      await t.tap(find.text('Send'));
      await t.pumpAndSettle();

      expect(api.sent.length, 1);
      expect(api.sent.single['kind'], 'feature_request');
    });
  });

  group('afterwards', () {
    testWidgets('they are thanked, not shown an error', (t) async {
      // They were generous enough to answer a prompt; an error about it is the
      // worst possible end to that.
      await open(t, _Recorder(succeeds: false));

      await t.tap(find.bySemanticsLabel('4 stars'));
      await t.pumpAndSettle();
      await t.tap(find.text('Send'));
      await t.pumpAndSettle();

      expect(find.text('Thank you'), findsOneWidget);
    });

    testWidgets('a successful answer stops the prompt coming back', (t) async {
      await open(t, _Recorder());

      await t.tap(find.bySemanticsLabel('5 stars'));
      await t.pumpAndSettle();
      await t.tap(find.text('Send'));
      await t.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('feedback.answered'), isTrue);
    });

    testWidgets('a send that failed is not recorded as answered', (t) async {
      // The opinion is asked for again rather than lost.
      await open(t, _Recorder(succeeds: false));

      await t.tap(find.bySemanticsLabel('5 stars'));
      await t.pumpAndSettle();
      await t.tap(find.text('Send'));
      await t.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('feedback.answered'), isNot(true));
      expect(prefs.getInt('feedback.lastAsked'), isNotNull);
    });
  });
}
