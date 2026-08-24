import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_action_sheet.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// The action menu as the conversation actually opens it: a real bottom-sheet
/// route pushed from a real bubble's gesture, not the sheet mounted on its own.
///
/// The isolated widget tests next door say the sheet draws the right rows. What
/// they cannot say is whether long-pressing a message opens exactly one of
/// them, which is where the interesting failures live.
final _now = DateTime(2026, 8, 24, 14, 50);

ChatMessage _message({String content = 'I am shooting at Central Park today!'}) =>
    ChatMessage(
      id: 'm1',
      roomId: 'r1',
      senderId: 'u1',
      senderName: 'Marcus Aurelius',
      senderRole: 'user',
      content: content,
      createdAt: _now,
    );

/// Mirrors what ChatRoomPage does on a long press.
Widget host({
  required ChatMessage message,
  VoidCallback? onReply,
  VoidCallback? onCopy,
  VoidCallback? onPin,
  bool isPinned = false,
}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(
          body: Builder(
            builder: (context) => Align(
              alignment: Alignment.topCenter,
              child: MessageBubble(
                message: message,
                isMe: false,
                onLongPress: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MessageActionSheet(
                    isPinned: isPinned,
                    onReply: () {
                      Navigator.pop(context);
                      onReply?.call();
                    },
                    onForward: () => Navigator.pop(context),
                    onCopy: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: message.content));
                      onCopy?.call();
                    },
                    onPin: () {
                      Navigator.pop(context);
                      onPin?.call();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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

  testWidgets('long-pressing a message opens the action menu', (t) async {
    await t.pumpWidget(host(message: _message()));

    expect(find.byType(MessageActionSheet), findsNothing);
    await t.longPress(find.textContaining('Central Park'));
    await t.pumpAndSettle();

    expect(find.byType(MessageActionSheet), findsOneWidget);
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget);
  });

  testWidgets('swiping a message opens the menu, and one dismissal closes it',
      (t) async {
    // Pushing a modal route cancels the drag, so the repeated handler calls the
    // old code made never became repeated sheets — this asserts the outcome
    // that was always true, so the swipe path stays covered either way. The
    // once-per-gesture guarantee is asserted on the handler itself, in
    // message_bubble_timestamp_test.dart.
    await t.pumpWidget(host(message: _message()));

    final gesture = await t.startGesture(t.getCenter(find.textContaining('Central Park')));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await t.pumpAndSettle();

    expect(find.byType(MessageActionSheet), findsOneWidget);

    // And it closes on one dismissal, leaving nothing behind it.
    await t.tapAt(const Offset(200, 60));
    await t.pumpAndSettle();
    expect(find.byType(MessageActionSheet), findsNothing);
  });

  testWidgets('Copy Text puts the message on the clipboard and closes the menu',
      (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await t.pumpWidget(host(message: _message()));
    await t.longPress(find.textContaining('Central Park'));
    await t.pumpAndSettle();

    await t.tap(find.text('Copy Text'));
    await t.pumpAndSettle();

    expect(copied, 'I am shooting at Central Park today!');
    expect(find.byType(MessageActionSheet), findsNothing);
  });

  testWidgets('Reply closes the menu and reports back', (t) async {
    var replied = false;
    await t.pumpWidget(host(message: _message(), onReply: () => replied = true));

    await t.longPress(find.textContaining('Central Park'));
    await t.pumpAndSettle();
    await t.tap(find.text('Reply'));
    await t.pumpAndSettle();

    expect(replied, isTrue);
    expect(find.byType(MessageActionSheet), findsNothing);
  });

  testWidgets('the menu offers Unpin for the message already pinned', (t) async {
    var pinToggled = false;
    await t.pumpWidget(host(
      message: _message(),
      isPinned: true,
      onPin: () => pinToggled = true,
    ));

    await t.longPress(find.textContaining('Central Park'));
    await t.pumpAndSettle();
    expect(find.text('Unpin'), findsOneWidget);

    await t.tap(find.text('Unpin'));
    await t.pumpAndSettle();
    expect(pinToggled, isTrue);
  });

  testWidgets('two long presses in a row do not leave a sheet behind',
      (t) async {
    await t.pumpWidget(host(message: _message()));

    for (var i = 0; i < 2; i++) {
      await t.longPress(find.textContaining('Central Park'));
      await t.pumpAndSettle();
      expect(find.byType(MessageActionSheet), findsOneWidget);
      await t.tap(find.text('Forward'));
      await t.pumpAndSettle();
      expect(find.byType(MessageActionSheet), findsNothing);
    }
  });
}
