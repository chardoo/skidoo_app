import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// The three tick states, and the one the app could not previously draw.
///
///   ✓        sent       the server has it
///   ✓✓ grey  delivered  it reached every other participant's device
///   ✓✓ blue  read       every one of them has opened it
///
/// The middle state needs `delivered_to`, which the server has broadcast all
/// along and the client never parsed. With only `read_by` to go on there was
/// nothing between "sent" and "read", so any message the other person had not
/// actively opened sat on a single tick — the "it is always one tick" report.
final _now = DateTime(2026, 9, 3, 14, 50);

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(
            body: Align(alignment: Alignment.topCenter, child: child)),
      ),
    );

ChatMessage _msg({
  List<String> readBy = const [],
  List<String> deliveredTo = const [],
  bool isLocal = false,
}) =>
    ChatMessage(
      id: 'm1',
      roomId: 'r1',
      senderId: 'me',
      senderName: 'Me',
      senderRole: 'user',
      content: 'Hello',
      createdAt: _now,
      readBy: readBy,
      deliveredTo: deliveredTo,
      isLocal: isLocal,
    );

Widget bubble(ChatMessage m, {required int totalOthers}) => MessageBubble(
      message: m,
      isMe: true,
      readCount: m.readBy.length,
      deliveredToCount: m.deliveredTo.length,
      totalOthers: totalOthers,
    );

/// The tick actually drawn, by icon.
Finder get oneTick => find.byIcon(Icons.done_rounded);
Finder get twoTicks => find.byIcon(Icons.done_all_rounded);
Finder get clock => find.byIcon(Icons.access_time_rounded);

Color tickColour(WidgetTester t, Finder f) => t.widget<Icon>(f).color!;

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('a direct message', () {
    testWidgets('sent but not yet delivered is one tick', (t) async {
      await t.pumpWidget(host(bubble(_msg(), totalOthers: 1)));

      expect(oneTick, findsOneWidget);
      expect(twoTicks, findsNothing);
    });

    testWidgets('delivered is two grey ticks', (t) async {
      // The state that was unreachable. Before `delivered_to` was parsed this
      // rendered exactly like the case above.
      await t.pumpWidget(host(
        bubble(_msg(deliveredTo: ['them']), totalOthers: 1),
      ));

      expect(twoTicks, findsOneWidget);
      expect(oneTick, findsNothing);
      expect(
        tickColour(t, twoTicks),
        isNot(AppThemeExtension.light.infoBlue),
        reason: 'delivered is grey; blue means read',
      );
    });

    testWidgets('read is two blue ticks', (t) async {
      await t.pumpWidget(host(
        bubble(_msg(deliveredTo: ['them'], readBy: ['them']), totalOthers: 1),
      ));

      expect(twoTicks, findsOneWidget);
      expect(tickColour(t, twoTicks), AppThemeExtension.light.infoBlue);
    });

    testWidgets('a read with no delivery row still shows blue', (t) async {
      // History from REST can carry a read without a matching delivery — a
      // client that was offline acks straight from history. Falling back to
      // `deliveredTo` alone would drop a blue message to one grey tick on
      // reload, a tick going *backwards*.
      await t.pumpWidget(host(
        bubble(_msg(readBy: ['them']), totalOthers: 1),
      ));

      expect(twoTicks, findsOneWidget);
      expect(tickColour(t, twoTicks), AppThemeExtension.light.infoBlue);
    });

    testWidgets('still sending is a clock, not a tick', (t) async {
      await t.pumpWidget(host(bubble(_msg(isLocal: true), totalOthers: 1)));

      expect(clock, findsOneWidget);
      expect(oneTick, findsNothing);
      expect(twoTicks, findsNothing);
    });
  });

  group('a group message', () {
    testWidgets('delivered to some of three is one tick', (t) async {
      await t.pumpWidget(host(
        bubble(_msg(deliveredTo: ['a']), totalOthers: 3),
      ));

      expect(oneTick, findsOneWidget);
    });

    testWidgets('delivered to all three is two grey ticks', (t) async {
      await t.pumpWidget(host(
        bubble(_msg(deliveredTo: ['a', 'b', 'c']), totalOthers: 3),
      ));

      expect(twoTicks, findsOneWidget);
      expect(tickColour(t, twoTicks), isNot(AppThemeExtension.light.infoBlue));
    });

    testWidgets('read by all three is two blue ticks', (t) async {
      await t.pumpWidget(host(
        bubble(
          _msg(deliveredTo: ['a', 'b', 'c'], readBy: ['a', 'b', 'c']),
          totalOthers: 3,
        ),
      ));

      expect(twoTicks, findsOneWidget);
      expect(tickColour(t, twoTicks), AppThemeExtension.light.infoBlue);
    });

    testWidgets('read by some names the number', (t) async {
      // "Some of the nine" is not a state two ticks can express.
      await t.pumpWidget(host(
        bubble(
          _msg(deliveredTo: ['a', 'b', 'c'], readBy: ['a']),
          totalOthers: 3,
        ),
      ));

      expect(find.text('Read by 1'), findsOneWidget);
    });
  });

  group('an unknown roster', () {
    testWidgets('claims one tick, not two', (t) async {
      // totalOthers == 0 means the room's participants have not loaded. All
      // that is known is that the server took the message; it used to draw a
      // confident double tick on no evidence at all.
      await t.pumpWidget(host(bubble(_msg(), totalOthers: 0)));

      expect(oneTick, findsOneWidget);
      expect(twoTicks, findsNothing);
    });
  });

  group('the model', () {
    test('reads delivered_to off the wire', () {
      final m = ChatMessage.fromJson({
        'id': 'm1',
        'room_id': 'r1',
        'sender_id': 'me',
        'sender_role': 'user',
        'created_at': _now.toUtc().toIso8601String(),
        'read_by': <String>['a'],
        'delivered_to': <String>['a', 'b'],
      });

      expect(m.readBy, ['a']);
      expect(m.deliveredTo, ['a', 'b']);
    });

    test('an older server that sends neither is quiet, not broken', () {
      final m = ChatMessage.fromJson({
        'id': 'm1',
        'room_id': 'r1',
        'sender_id': 'me',
        'sender_role': 'user',
        'created_at': _now.toUtc().toIso8601String(),
      });

      expect(m.deliveredTo, isEmpty);
      expect(m.readBy, isEmpty);
    });
  });
}
