import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/photographers/data/repositories/reviews_repository.dart';
import 'package:jperg_app/features/photographers/presentation/pages/reviews_pages.dart';

/// Opening the composer for a photographer you have already reviewed.
///
/// A review stands once published — the server refuses a second, and that rule
/// is right: it stops a rating being walked up or down from a screen. What was
/// wrong is that nothing said so until *after* the work. The composer opened
/// empty, offered five stars and a thousand characters, and answered the
/// submit with a red snackbar. The rule read as a broken button.
///
/// So the composer now asks first, shows what they wrote, and says plainly
/// that it stands.
void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  /// A repository answering `…/review/mine` with whatever the test supplies.
  ReviewsRepository repoAnswering(
    Map<String, dynamic>? review, {
    bool fails = false,
  }) {
    final client = dio.Dio()
      ..httpClientAdapter = _Adapter((_) {
        if (fails) throw StateError('offline');
        return {'data': review};
      });
    return ReviewsRepository(client: client);
  }

  Widget host(ReviewsRepository repo) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: WriteReviewPage(
            photographerId: 'ph-1',
            photographerName: 'Joe',
            requestTitle: 'Trip Creator',
            repo: repo,
          ),
        ),
      );

  testWidgets('an existing review is shown, not an empty form', (t) async {
    final repo = repoAnswering({
      'id': 'r1',
      'rating': 5,
      'comment': 'Brilliant on the day.',
      'createdAt': '2026-09-20T10:00:00Z',
    });

    await t.pumpWidget(host(repo));
    await t.pumpAndSettle();

    expect(find.text('Brilliant on the day.'), findsOneWidget);
  });

  testWidgets('and it says so before anything is filled in', (t) async {
    await t.pumpWidget(host(
        repoAnswering({'id': 'r1', 'rating': 5, 'comment': 'Great'})));
    await t.pumpAndSettle();

    expect(find.textContaining('You reviewed Joe'), findsOneWidget);
  });

  testWidgets('the button is spent rather than live', (t) async {
    // Live and guaranteed to fail is the shape this was reported for.
    await t.pumpWidget(
        host(repoAnswering({'id': 'r1', 'rating': 4, 'comment': ''})));
    await t.pumpAndSettle();

    expect(find.text('Already Reviewed'), findsOneWidget);
    final button = t.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('somebody who has not reviewed gets a working form', (t) async {
    await t.pumpWidget(host(repoAnswering(null)));
    await t.pumpAndSettle();

    expect(find.text('Submit Review'), findsOneWidget);
    expect(find.textContaining('You reviewed'), findsNothing);
  });

  testWidgets('a failed lookup still opens the form', (t) async {
    // The prefill is a courtesy; the server is the authority. A blip should
    // cost the prefill, not the ability to leave a review.
    await t.pumpWidget(host(repoAnswering(null, fails: true)));
    await t.pumpAndSettle();

    expect(find.text('Submit Review'), findsOneWidget);
  });
}

/// Answers every request from a callback, with no socket.
class _Adapter implements dio.HttpClientAdapter {
  _Adapter(this.respond);

  final Map<String, dynamic> Function(String path) respond;

  @override
  Future<dio.ResponseBody> fetch(dio.RequestOptions options,
      Stream<List<int>>? _, Future<void>? __) async {
    return dio.ResponseBody.fromString(
      jsonEncode(respond(options.path)),
      200,
      headers: {
        dio.Headers.contentTypeHeader: [dio.Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
