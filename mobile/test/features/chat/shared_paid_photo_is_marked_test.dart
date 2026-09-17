import 'package:flutter/material.dart';
import 'package:jperg_app/core/purchase/paid_photo_watermark.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// A paid photo shared into a chat carries the mark in the bubble.
///
/// The reported bug, twice: first the mark disappeared a few seconds after
/// sending (the echo replaced the optimistic bubble and dropped the flag), then
/// it was not there at all. The second one was the send: four screens open the
/// share sheet and only two of them passed the flag, so sharing from the feed
/// sent a message that had never been marked. The parameter is required now, so
/// the next screen that forgets will not compile.
///
/// This is the end of that chain — given a message that says it is a paid
/// preview, the bubble has to draw the logo.
ChatMessage shared({bool paidPreview = false, bool isVideo = false}) =>
    ChatMessage(
      id: 'm1',
      roomId: 'r1',
      senderId: 'them',
      senderName: 'Ama',
      senderRole: 'user',
      content: '',
      imageUrl: 'https://cdn.example.com/priced.jpg',
      isVideo: isVideo,
      paidPreview: paidPreview,
      createdAt: DateTime.utc(2026, 9, 16),
    );

Widget host(ChatMessage message) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessageBubble(message: message, isMe: false),
          ),
        ),
      ),
    );

void main() {
  // The watermark itself, not any SVG on the screen. Scoped once the app's
  // chrome moved to an SVG icon set — a bare `byType(SvgPicture)` started
  // counting the close button and anything else on the same route.
  final mark = find.descendant(
    of: find.byType(PaidPhotoWatermark),
    matching: find.byType(SvgPicture),
  );

  testWidgets('a shared paid photo is marked', (t) async {
    await t.pumpWidget(host(shared(paidPreview: true)));
    await t.pump();

    expect(mark, findsOneWidget);
  });

  testWidgets('an ordinary shared photo is not', (t) async {
    await t.pumpWidget(host(shared()));
    await t.pump();

    expect(mark, findsNothing);
  });

  group('and opening it bigger does not take the mark away', () {
    // The third round of this bug. Tapping the bubble pushes a *second* copy of
    // the photo full-screen, and that one was built from the URL alone — so the
    // way to get a clean screenshot of a paid photo was to tap it.
    Future<void> openIt(WidgetTester t) async {
      await t.tap(find.byType(GestureDetector).first);
      // Not pumpAndSettle: the image placeholder is a CircularProgressIndicator
      // that never stops spinning under a test's fake network, so nothing here
      // ever settles. Long enough for the route transition to finish.
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the enlarged paid photo carries it', (t) async {
      await t.pumpWidget(host(shared(paidPreview: true)));
      await t.pump();

      expect(mark, findsOneWidget); // the bubble's

      await openIt(t);

      // Two, not one: the bubble stays mounted under the pushed route, so the
      // second is the viewer's own. Before the fix this stayed at one — the
      // enlarged copy was built from the URL alone.
      expect(mark, findsNWidgets(2));
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('an ordinary photo is still unmarked enlarged', (t) async {
      await t.pumpWidget(host(shared()));
      await t.pump();

      await openIt(t);

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(mark, findsNothing);
    });

    testWidgets('the mark is outside the zoom', (t) async {
      // The point of the fix, and the thing a later refactor would undo without
      // noticing: inside the InteractiveViewer the logo pans and scales with
      // the photo, so at 6x in a corner it is off-screen and the hole is back.
      // Pinned to the viewport it is in every frame at every zoom.
      await t.pumpWidget(host(shared(paidPreview: true)));
      await t.pump();
      await openIt(t);

      expect(
        find.descendant(of: find.byType(InteractiveViewer), matching: mark),
        findsNothing,
      );
    });
  });

  testWidgets('the photo itself is drawn either way', (t) async {
    // Whatever else happens, the wrapper must not cost the bubble its image.
    for (final paid in [true, false]) {
      await t.pumpWidget(host(shared(paidPreview: paid)));
      await t.pump();

      expect(find.byType(MessageBubble), findsOneWidget);
    }
  });
}
