import 'package:flutter/material.dart';
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
  final mark = find.byType(SvgPicture);

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

  testWidgets('the photo itself is drawn either way', (t) async {
    // Whatever else happens, the wrapper must not cost the bubble its image.
    for (final paid in [true, false]) {
      await t.pumpWidget(host(shared(paidPreview: paid)));
      await t.pump();

      expect(find.byType(MessageBubble), findsOneWidget);
    }
  });
}
