/// What a wrong event code says.
///
/// A scanned code that names no event used to arrive on the result screen as
/// "No photos of you yet — We didn't find you in this event", which is the one
/// sentence here that is not true. It asserts the event is real and that the
/// person simply is not in it, so the obvious response is to shrug rather than
/// to check the code.
///
/// Two things caused it. The data layer threw the server's answer away and
/// reported `'Scan failed: 404'`, and the screen then asked `/client/my-photos`
/// for the album — a query that succeeds and returns nothing for a code that
/// names nothing, which is indistinguishable from a real event this person is
/// in none of.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jperg_app/core/common/widgets/app_error_view.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/event_scan.dart';

/// The server's envelope, as the real one answers it.
http.StreamedResponse _response(int status, {Object? body}) =>
    http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body ?? const {}))),
      status,
    );

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('reading the server', () {
    test('a 404 is the event, not the search', () async {
      final failure = await failureFrom(
        _response(404, body: {
          'success': false,
          'error': {
            'code': 'NOT_FOUND',
            'message': 'That event does not exist',
            'statusCode': 404,
          },
        }),
      );

      expect(failure, isA<EventNotFound>());
      expect('$failure', 'That event does not exist');
    });

    test('it carries the server\'s own words', () async {
      final failure = await failureFrom(
        _response(404, body: {
          'error': {'message': 'That album was taken down'},
        }),
      );

      expect((failure as EventNotFound).message, 'That album was taken down');
    });

    test('a 404 with no envelope still says the useful thing', () async {
      // Reverse proxies answer 404 in their own HTML. The status is enough to
      // know what happened; the sentence is ours.
      final failure = await failureFrom(
        http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('<html>Not Found</html>')),
          404,
        ),
      );

      expect(failure, isA<EventNotFound>());
      expect('$failure', 'That event does not exist');
    });

    test('other failures are not mistaken for a missing event', () async {
      final failure = await failureFrom(
        _response(500, body: {
          'error': {'message': 'Face service unavailable'},
        }),
      );

      expect(failure, isNot(isA<EventNotFound>()));
      expect(failure, 'Face service unavailable');
    });

    test('a failure with nothing to say still says something', () async {
      final failure = await failureFrom(_response(502));

      expect(failure, isNot(isA<EventNotFound>()));
      // Not "Scan failed: 502", which is the status code wearing a sentence.
      expect('$failure', contains('try again'));
      expect('$failure', isNot(contains('502')));
    });
  });

  group('what it offers', () {
    testWidgets('a missing event does not offer to try the same code again',
        (tester) async {
      await tester.pumpWidget(_host(const AppErrorView(
        message: 'That event does not exist',
        onRetry: null,
      )));
      await tester.pump();

      expect(find.text('That event does not exist'), findsOneWidget);
      // Retrying a code that names nothing answers the same every time.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a real failure still offers another go', (tester) async {
      var retried = false;
      await tester.pumpWidget(_host(AppErrorView(
        message: 'That search could not be run just now.',
        onRetry: () => retried = true,
      )));
      await tester.pump();

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('the button can name the way forward', (tester) async {
      await tester.pumpWidget(_host(AppErrorView(
        message: 'That event does not exist',
        retryLabel: 'Try another code',
        onRetry: () {},
      )));
      await tester.pump();

      expect(find.text('Try another code'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('the screen tells the two apart', () {
    const page =
        'lib/features/gallery/presentation/found/pages/event_scan_result_page.dart';

    test('a missing event is answered before the album is asked for', () {
      final source = File(page).readAsStringSync();

      // Scoped to _showResult. The page queries albums twice — the other is
      // "View now", which only runs once photos have already arrived, so a
      // missing event can never reach it.
      final start = source.indexOf('Future<void> _showResult()');
      expect(start, isNot(-1), reason: '_showResult moved');
      final body = source.substring(start, source.indexOf('void _openAlbum()'));

      final guard = body.indexOf('is EventNotFound');
      final query = body.indexOf('GetFoundPhotosUseCase>().albums');
      expect(guard, isNot(-1), reason: '_showResult must check for it');
      expect(query, isNot(-1), reason: '_showResult still queries albums');
      expect(
        guard < query,
        isTrue,
        reason: 'the album query succeeds and returns nothing for a code that '
            'names nothing — which reads as "no photos of you"',
      );
    });

    test('neither search reports a bare status code any more', () {
      for (final path in const [
        'lib/features/gallery/data/event_scan.dart',
        'lib/features/gallery/data/easy_search.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('failureFrom(response)'));
        expect(source, isNot(contains(r"failed: ${response.statusCode}")));
      }
    });
  });
}
