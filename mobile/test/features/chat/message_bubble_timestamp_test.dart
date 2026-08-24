import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// The designs put the time inside the bubble, in its bottom-right corner —
/// not on a line of its own underneath every message.
final _now = DateTime(2026, 8, 24, 14, 50);

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(
            body: Align(alignment: Alignment.topCenter, child: child)),
      ),
    );

ChatMessage _message({String content = 'Hello', String? imageUrl}) =>
    ChatMessage(
      id: 'm1',
      roomId: 'r1',
      senderId: 'u1',
      senderName: 'Kwame',
      senderRole: 'user',
      content: content,
      imageUrl: imageUrl,
      createdAt: _now,
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('the time sits inside the bubble on a text message', (t) async {
    await t.pumpWidget(
        host(MessageBubble(message: _message(), isMe: true)));

    final time = find.text('2:50 PM');
    expect(time, findsOneWidget);

    // The bubble is the decorated Container; the timestamp being inside its
    // bounds is the whole change.
    final bubble = t.getRect(find.byType(Container).first);
    final timeRect = t.getRect(time);
    expect(bubble.contains(timeRect.centerLeft), isTrue);
    expect(bubble.contains(timeRect.centerRight), isTrue);
  });

  testWidgets('a media-only bubble keeps the time underneath', (t) async {
    await t.pumpWidget(host(MessageBubble(
      message: _message(content: '', imageUrl: 'https://example.com/a.jpg'),
      isMe: true,
    )));

    final time = find.text('2:50 PM');
    expect(time, findsOneWidget);

    final bubble = t.getRect(find.byType(Container).first);
    final timeRect = t.getRect(time);
    expect(timeRect.top, greaterThanOrEqualTo(bubble.bottom));
  });

  testWidgets('a captioned photo keeps its caption left and its time right',
      (t) async {
    await t.pumpWidget(host(MessageBubble(
      message: _message(
          content: 'Ok', imageUrl: 'https://example.com/a.jpg'),
      isMe: true,
    )));

    final caption = t.getRect(find.text('Ok'));
    final time = t.getRect(find.text('2:50 PM'));
    // The bubble is as wide as the photo, so a two-letter caption must not be
    // dragged over to the right edge with the timestamp.
    expect(caption.left, lessThan(time.left));
    expect(time.top, greaterThan(caption.top));
  });

  testWidgets('one swipe fires the action handler once, not once per pixel',
      (t) async {
    // onHorizontalDragUpdate fires on every pointer move, and the handler used
    // to run on each one — about ten times per swipe. Opening a modal route
    // happens to absorb the rest, so the menu itself only appeared once, but
    // the handler is the callers' contract and it should fire once per gesture.
    var calls = 0;
    await t.pumpWidget(host(MessageBubble(
      message: _message(),
      isMe: true,
      onLongPress: () => calls++,
    )));

    final gesture = await t.startGesture(t.getCenter(find.text('Hello')));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await t.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('a sideways slip while scrolling is not a swipe', (t) async {
    // Long enough that the recognizer has claimed the pointer and is delivering
    // updates — the range where the old code opened the menu on an accidental
    // drift — but short of the travel the bubble asks for before it acts.
    var calls = 0;
    await t.pumpWidget(host(MessageBubble(
      message: _message(),
      isMe: true,
      onLongPress: () => calls++,
    )));

    final gesture = await t.startGesture(t.getCenter(find.text('Hello')));
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(const Offset(6, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await t.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('a received message reads its time in the muted colour',
      (t) async {
    await t.pumpWidget(
        host(MessageBubble(message: _message(), isMe: false)));

    final time = t.widget<Text>(find.text('2:50 PM'));
    expect(time.style!.color, AppThemeExtension.light.searchHintColor);
  });

  testWidgets('a sent message reads its time against the filled bubble',
      (t) async {
    await t.pumpWidget(
        host(MessageBubble(message: _message(), isMe: true)));

    final time = t.widget<Text>(find.text('2:50 PM'));
    // White at reduced opacity — the theme's grey would vanish into the accent.
    expect(time.style!.color, Colors.white.withValues(alpha: 0.75));
  });
}
