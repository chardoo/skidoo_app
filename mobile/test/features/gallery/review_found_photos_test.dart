import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/repositories/found_review_repository.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/review_found_photos_page.dart';

/// The review screen decides which photos are really of you, and everything
/// after it — what is in your photos, what a rescan may re-add — follows from
/// that answer. What matters here is that the count says what will be sent and
/// that closing sends nothing.
PendingFound _pending({int events = 1, int perEvent = 3}) => PendingFound(
      total: events * perEvent,
      eventCount: events,
      coverUrl: 'https://example.com/cover.jpg',
      events: [
        for (var e = 0; e < events; e++)
          PendingFoundEvent(
            id: 'evt-$e',
            eventName: 'Event $e',
            photos: [
              for (var p = 0; p < perEvent; p++)
                PendingFoundPhoto(id: 'e${e}p$p', url: 'https://example.com/$e$p.jpg'),
            ],
          ),
      ],
    );

Future<void> _pump(WidgetTester tester, PendingFound pending) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: ReviewFoundPhotosPage(pending: pending),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('everything starts selected', (tester) async {
    // Recognition is usually right, so "yes, all of these" is the common
    // answer and deselecting is what costs a tap.
    await _pump(tester, _pending(perEvent: 3));

    expect(find.text('Confirm 3 photos'), findsOneWidget);
    expect(find.text('Not me'), findsNothing);
  });

  testWidgets('deselecting marks the photo and drops the count',
      (tester) async {
    await _pump(tester, _pending(perEvent: 3));

    await tester.tapAt(tester.getCenter(find.byType(Image).first));
    await tester.pump();

    expect(find.text('Not me'), findsOneWidget);
    expect(find.text('Confirm 2 photos'), findsOneWidget);
  });

  testWidgets('tapping again puts it back', (tester) async {
    await _pump(tester, _pending(perEvent: 3));

    await tester.tapAt(tester.getCenter(find.byType(Image).first));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(Image).first));
    await tester.pump();

    expect(find.text('Not me'), findsNothing);
    expect(find.text('Confirm 3 photos'), findsOneWidget);
  });

  testWidgets('one photo is singular', (tester) async {
    await _pump(tester, _pending(perEvent: 1));

    expect(find.text('Confirm 1 photo'), findsOneWidget);
  });

  testWidgets('deselecting everything is still an answer', (tester) async {
    // "None of these are me" is a real answer and has to be sendable, so the
    // button says what it will do rather than going dead.
    await _pump(tester, _pending(perEvent: 2));

    await tester.tapAt(tester.getCenter(find.byType(Image).at(0)));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(Image).at(1)));
    await tester.pump();

    expect(find.text('Confirm none are you'), findsOneWidget);
  });

  testWidgets('several events are grouped under their names', (tester) async {
    await _pump(tester, _pending(events: 2, perEvent: 2));

    expect(find.text('Event 0'), findsOneWidget);
    expect(find.text('Event 1'), findsOneWidget);
    expect(find.text('Confirm 4 photos'), findsOneWidget);
  });

  testWidgets('a single event needs no heading', (tester) async {
    await _pump(tester, _pending(events: 1, perEvent: 2));

    // The whole screen is that event; naming it would be repeating the banner.
    expect(find.text('Event 0'), findsNothing);
  });

  testWidgets('closing answers nothing', (tester) async {
    bool? result;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: ThemeData(extensions: const [AppThemeExtension.light]),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReviewFoundPhotosPage(pending: _pending(perEvent: 2)),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // False, not null: the caller keeps the banner and leaves the photos
    // waiting rather than assuming they were answered.
    expect(result, isFalse);
  });
}
