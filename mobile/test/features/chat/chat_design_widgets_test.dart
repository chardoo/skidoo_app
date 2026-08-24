import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/mentions.dart';
import 'package:jperg_app/features/chat/presentation/widgets/mention_picker.dart';
import 'package:jperg_app/features/chat/presentation/widgets/mention_text.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_action_sheet.dart';
import 'package:jperg_app/features/chat/presentation/widgets/pinned_message_banner.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(body: child),
      ),
    );

ChatParticipant _p(String id, String name) => ChatParticipant(
      userId: id,
      userRole: 'user',
      userName: name,
      joinedAt: DateTime(2026, 8, 24),
    );

void main() {
  group('MessageActionSheet', () {
    testWidgets('offers every action the designs list', (t) async {
      await t.pumpWidget(host(MessageActionSheet(
        onReply: () {},
        onForward: () {},
        onCopy: () {},
        onPin: () {},
        onDelete: () {},
      )));

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Forward'), findsOneWidget);
      expect(find.text('Copy Text'), findsOneWidget);
      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('omits rows that do not apply rather than greying them',
        (t) async {
      await t.pumpWidget(host(MessageActionSheet(onReply: () {})));

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy Text'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('the pinned message offers Unpin instead of Pin', (t) async {
      await t.pumpWidget(host(MessageActionSheet(
        onReply: () {},
        onPin: () {},
        isPinned: true,
      )));

      expect(find.text('Unpin'), findsOneWidget);
      expect(find.text('Pin'), findsNothing);
    });

    testWidgets('Delete is the only coloured row', (t) async {
      await t.pumpWidget(host(MessageActionSheet(
        onReply: () {},
        onDelete: () {},
      )));

      final delete = t.widget<Text>(find.text('Delete'));
      final reply = t.widget<Text>(find.text('Reply'));
      expect(delete.style!.color, AppThemeExtension.light.errorRed);
      expect(reply.style!.color, isNot(AppThemeExtension.light.errorRed));
    });

    testWidgets('tapping a row runs its action', (t) async {
      var forwarded = false;
      await t.pumpWidget(host(MessageActionSheet(
        onReply: () {},
        onForward: () => forwarded = true,
      )));

      await t.tap(find.text('Forward'));
      expect(forwarded, isTrue);
    });
  });

  group('PinnedMessageBanner', () {
    PinnedMessage pinned({String? content, String? imageUrl, bool video = false}) =>
        PinnedMessage(
          id: 'm1',
          senderId: 'u1',
          senderName: 'Marcus',
          content: content,
          imageUrl: imageUrl,
          isVideo: video,
          createdAt: DateTime(2026, 8, 24),
        );

    testWidgets('names itself and shows one line of the message', (t) async {
      await t.pumpWidget(host(PinnedMessageBanner(
        pinned: pinned(
            content:
                'Definitely pack an 85mm prime. It isolates subjects beautifully.'),
      )));

      expect(find.text('PINNED MESSAGE'), findsOneWidget);
      final preview = t.widget<Text>(find.textContaining('85mm prime'));
      expect(preview.maxLines, 1);
      expect(preview.overflow, TextOverflow.ellipsis);
    });

    testWidgets('an attachment with no caption still says what was pinned',
        (t) async {
      await t.pumpWidget(host(PinnedMessageBanner(
        pinned: pinned(imageUrl: 'https://example.com/a.jpg'),
      )));
      expect(find.text('Photo'), findsOneWidget);

      await t.pumpWidget(host(PinnedMessageBanner(
        pinned: pinned(imageUrl: 'https://example.com/a.mp4', video: true),
      )));
      expect(find.text('Video'), findsOneWidget);
    });

    testWidgets('has no unpin control when the reader may not change the pin',
        (t) async {
      await t.pumpWidget(host(PinnedMessageBanner(pinned: pinned(content: 'x'))));
      await t.pump();
      expect(find.byKey(PinnedMessageBanner.unpinKey), findsNothing);
    });

    testWidgets('offers the unpin control when the reader may change the pin',
        (t) async {
      await t.pumpWidget(host(PinnedMessageBanner(
        pinned: pinned(content: 'x'),
        onUnpin: () {},
      )));
      await t.pump();
      expect(find.byKey(PinnedMessageBanner.unpinKey), findsOneWidget);
    });

    testWidgets('the pin icon on the left is what unpins, per the designs',
        (t) async {
      var jumped = false;
      var unpinned = false;
      await t.pumpWidget(host(PinnedMessageBanner(
        pinned: pinned(content: 'x'),
        onTap: () => jumped = true,
        onUnpin: () => unpinned = true,
      )));

      // The design has no control on the right — the struck-through pin is it.
      final icon = t.getRect(find.byIcon(Icons.push_pin_outlined));
      final label = t.getRect(find.text('PINNED MESSAGE'));
      expect(icon.left, lessThan(label.left));

      await t.tap(find.byKey(PinnedMessageBanner.unpinKey));
      expect(unpinned, isTrue);
      expect(jumped, isFalse);
    });

    testWidgets('tapping the strip itself jumps to the message', (t) async {
      var jumped = false;
      await t.pumpWidget(host(PinnedMessageBanner(
        pinned: pinned(content: 'pack an 85mm prime'),
        onTap: () => jumped = true,
        onUnpin: () {},
      )));

      await t.tap(find.text('pack an 85mm prime'));
      expect(jumped, isTrue);
    });
  });

  group('MentionPicker', () {
    testWidgets('lists each candidate with their handle', (t) async {
      final people = [_p('u1', 'Devon A'), _p('u2', 'Sara Johnson')];
      await t.pumpWidget(host(MentionPicker(
        participants: people,
        handles: Mentions.handlesFor(people),
        onSelected: (_) {},
      )));

      expect(find.text('Devon A'), findsOneWidget);
      expect(find.text('@devon_a'), findsOneWidget);
      expect(find.text('Sara Johnson'), findsOneWidget);
      expect(find.text('@sara_j'), findsOneWidget);
    });

    testWidgets('reports the tapped member', (t) async {
      final people = [_p('u1', 'Devon A'), _p('u2', 'Sara Johnson')];
      ChatParticipant? picked;
      await t.pumpWidget(host(MentionPicker(
        participants: people,
        handles: Mentions.handlesFor(people),
        onSelected: (p) => picked = p,
      )));

      await t.tap(find.text('Sara Johnson'));
      expect(picked?.userId, 'u2');
    });
  });

  group('MentionText', () {
    const style = TextStyle(fontSize: 14, color: Colors.black);
    const mentionStyle = TextStyle(color: Colors.green, fontWeight: FontWeight.w700);

    testWidgets('a body with no mentions stays a plain Text', (t) async {
      await t.pumpWidget(host(const MentionText(
        text: 'no mentions here',
        style: style,
        mentionStyle: mentionStyle,
      )));

      final text = t.widget<Text>(find.byType(Text));
      expect(text.textSpan, isNull);
      expect(text.data, 'no mentions here');
    });

    testWidgets('a mention is styled apart from the rest of the line',
        (t) async {
      final people = [_p('me', 'Kwame Owusu')];
      final handles = Mentions.handlesFor(people);
      await t.pumpWidget(host(MentionText(
        text: 'Hey @kwame_o, ready?',
        style: style,
        mentionStyle: mentionStyle,
        handles: handles,
        displayNames: const {'me': 'Kwame Owusu'},
        myUserId: 'me',
      )));

      final rendered = t.widget<Text>(find.byType(Text));
      final children = (rendered.textSpan! as TextSpan).children!;
      final mention = children.firstWhere(
              (span) => (span as TextSpan).text == '@You') as TextSpan;
      expect(mention.style!.color, Colors.green);
      expect(mention.style!.fontWeight, FontWeight.w700);
    });
  });
}
