import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// A bubble is sized by what it says. The Column inside it used to stretch —
/// which media needs, but which also handed every text-only bubble the full 72%
/// it was allowed, so "Bro" drew the same wide slab as a paragraph.
final _now = DateTime(2026, 8, 16, 12);

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(body: Align(alignment: Alignment.topCenter, child: child)),
      ),
    );

ChatMessage _message(String content, {ReplyPreview? reply}) => ChatMessage(
      id: content,
      roomId: 'r1',
      senderId: 'u1',
      senderName: 'Kwame',
      senderRole: 'user',
      content: content,
      replyPreview: reply,
      createdAt: _now,
    );

Future<double> _bubbleWidth(WidgetTester t, ChatMessage message) async {
  await t.pumpWidget(host(MessageBubble(message: message, isMe: true)));
  await t.pumpAndSettle();
  return t.getSize(find.byType(Container).first).width;
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('a short message gets a short bubble', (t) async {
    final short = await _bubbleWidth(t, _message('Bro'));
    final long = await _bubbleWidth(
      t,
      _message('Are we still meeting at Central Park this evening?'),
    );

    expect(short, lessThan(long));
    // "Bro" plus 14 of padding each side lands near 80; nowhere near the 72%
    // (≈281) it used to take.
    expect(short, lessThan(120));
  });

  testWidgets('a long message still stops at the 72% cap', (t) async {
    final width = await _bubbleWidth(
      t,
      _message('Bro ' * 60),
    );
    expect(width, closeTo(390 * 0.72, 2));
  });

  testWidgets('a short reply does not drag the bubble out to full width',
      (t) async {
    final width = await _bubbleWidth(
      t,
      _message(
        'Yes',
        reply: const ReplyPreview(id: 'm0', senderName: 'Sarah', content: 'Ok?'),
      ),
    );
    expect(width, lessThan(390 * 0.72));
  });
}
