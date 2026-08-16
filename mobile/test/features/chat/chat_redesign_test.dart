import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/day_separator.dart';
import 'package:jperg_app/features/chat/presentation/widgets/room_tile.dart';
import 'package:jperg_app/features/chat/presentation/widgets/system_notice_text.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

const me = 'u1';
const peer = 'u2';
final now = DateTime(2026, 8, 16, 12);

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(body: child),
      ),
    );

ChatParticipant participant(
  String id, {
  String? name,
  String? image,
  String status = 'active',
  bool isAdmin = false,
  bool muted = false,
  String? invitedByName,
}) =>
    ChatParticipant(
      userId: id,
      userRole: 'user',
      joinedAt: now,
      status: status,
      userName: name,
      userImage: image,
      isAdmin: isAdmin,
      muted: muted,
      invitedByName: invitedByName,
    );

ChatRoom room({
  RoomType type = RoomType.direct,
  String? name,
  String? imageUrl,
  List<ChatParticipant>? participants,
  LastMessage? lastMessage,
}) =>
    ChatRoom(
      id: 'r1',
      type: type,
      name: name,
      imageUrl: imageUrl,
      createdAt: now,
      participants: participants ??
          [participant(me, name: 'Me'), participant(peer, name: 'Sarah Johnson')],
      lastMessage: lastMessage,
    );

LastMessage last({
  String senderId = peer,
  String senderName = 'Sarah Johnson',
  String? content,
  bool hasImage = false,
  bool isEncrypted = false,
  String? systemType,
}) =>
    LastMessage(
      id: 'm1',
      senderId: senderId,
      senderName: senderName,
      content: content,
      hasImage: hasImage,
      isEncrypted: isEncrypted,
      systemType: systemType,
      createdAt: now,
    );

Future<void> pumpTile(WidgetTester t, ChatRoom r, {String? previewOverride}) =>
    t.pumpWidget(host(RoomTile(
      room: r,
      currentUserId: me,
      previewOverride: previewOverride,
      onTap: () {},
    )));

void main() {
  // ── The preview line ────────────────────────────────────────────────────
  //
  // The inbox tile has one line to say what happened last, and the answer comes
  // from several places: the server's preview, the local cache, or a
  // description of the room when nothing has been said at all.
  group('room tile preview', () {
    testWidgets('shows the last message in a DM', (t) async {
      await pumpTile(t, room(lastMessage: last(content: 'Are we still on?')));
      expect(find.text('Are we still on?'), findsOneWidget);
    });

    testWidgets('names the speaker in a group', (t) async {
      // A DM has one other person in it, so attributing every line is noise.
      // A group needs it to be readable at all.
      await pumpTile(
        t,
        room(type: RoomType.group, name: 'Team', lastMessage: last(content: 'On my way')),
      );
      expect(find.text('Sarah: On my way'), findsOneWidget);
    });

    testWidgets('says "You" for your own message in a group', (t) async {
      await pumpTile(
        t,
        room(
          type: RoomType.group,
          name: 'Team',
          lastMessage: last(senderId: me, senderName: 'Me', content: 'On my way'),
        ),
      );
      expect(find.text('You: On my way'), findsOneWidget);
    });

    testWidgets('describes an image-only message', (t) async {
      // There is no text to show, so without this an image send reads as an
      // empty conversation.
      await pumpTile(t, room(lastMessage: last(hasImage: true)));
      expect(find.text('Sent a photo'), findsOneWidget);
    });

    testWidgets('never prints ciphertext', (t) async {
      await pumpTile(
        t,
        room(lastMessage: last(content: null, isEncrypted: true)),
      );
      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets('renders a system notice as its sentence', (t) async {
      await pumpTile(
        t,
        room(
          type: RoomType.group,
          name: 'Team',
          lastMessage: last(systemType: 'invite_accepted'),
        ),
      );
      expect(find.text('Sarah Johnson accepted group invite'), findsOneWidget);
    });

    testWidgets('falls back to the local cache when the server sent none',
        (t) async {
      // Offline cold start: the room list has no preview, but the message cache
      // does.
      await pumpTile(t, room(), previewOverride: 'from the cache');
      expect(find.text('from the cache'), findsOneWidget);
    });

    testWidgets('the server preview wins over the cached one', (t) async {
      await pumpTile(
        t,
        room(lastMessage: last(content: 'newer')),
        previewOverride: 'older',
      );
      expect(find.text('newer'), findsOneWidget);
      expect(find.text('older'), findsNothing);
    });

    testWidgets('an empty room describes itself instead', (t) async {
      await pumpTile(
        t,
        room(
          type: RoomType.group,
          name: 'Team',
          participants: [
            participant(me, name: 'Me'),
            participant(peer, name: 'Sarah'),
            participant('u3', name: 'Devon'),
          ],
        ),
      );
      expect(find.text('3 members'), findsOneWidget);
    });

    testWidgets('a muted room is marked', (t) async {
      await pumpTile(
        t,
        room(participants: [
          participant(me, name: 'Me', muted: true),
          participant(peer, name: 'Sarah Johnson'),
        ]),
      );
      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    });
  });

  // ── System notice wording ───────────────────────────────────────────────

  group('system notices', () {
    test('addresses you as "You"', () {
      expect(
        systemNoticeText(
            systemType: 'group_created', actorName: 'Sara', isMe: true),
        'You created this group',
      );
    });

    test('names anyone else', () {
      expect(
        systemNoticeText(
            systemType: 'invite_declined', actorName: 'Sara', isMe: false),
        'Sara declined group invite',
      );
    });

    test('an unknown type renders as nothing, not a blank line', () {
      // A newer server adding a notice type must not punch a hole in an older
      // app's conversation.
      expect(
        systemNoticeText(
            systemType: 'something_new', actorName: 'Sara', isMe: false),
        isNull,
      );
    });

    test('a nameless actor still reads as a sentence', () {
      expect(
        systemNoticeText(systemType: 'invite_accepted', actorName: '', isMe: false),
        'Someone accepted group invite',
      );
    });
  });

  // ── Day separators ──────────────────────────────────────────────────────

  group('day separators', () {
    test('today and yesterday are named', () {
      final today = DateTime.now();
      expect(DaySeparator.label(today), 'Today');
      expect(
        DaySeparator.label(today.subtract(const Duration(days: 1))),
        'Yesterday',
      );
    });

    test('a separator is needed only when the day changes', () {
      final morning = DateTime(2026, 8, 16, 9);
      final evening = DateTime(2026, 8, 16, 23, 59);
      final nextDay = DateTime(2026, 8, 17, 0, 1);

      expect(DaySeparator.needsSeparator(morning, evening), isFalse);
      // One minute apart, but a different day — the case a naive duration check
      // gets wrong.
      expect(DaySeparator.needsSeparator(evening, nextDay), isTrue);
    });

    test('the same day in a different year is still a new day', () {
      expect(
        DaySeparator.needsSeparator(
            DateTime(2025, 8, 16), DateTime(2026, 8, 16)),
        isTrue,
      );
    });
  });

  // ── Room helpers ────────────────────────────────────────────────────────

  group('ChatRoom', () {
    test('a DM shows the other person\'s avatar, not your own', () {
      final r = room(participants: [
        participant(me, name: 'Me', image: 'mine.jpg'),
        participant(peer, name: 'Sarah', image: 'theirs.jpg'),
      ]);
      expect(r.avatarFor(me), 'theirs.jpg');
    });

    test('a group shows its own photo', () {
      final r = room(type: RoomType.group, name: 'Team', imageUrl: 'group.jpg');
      expect(r.avatarFor(me), 'group.jpg');
    });

    test('no avatar anywhere is null, not an empty string', () {
      expect(room().avatarFor(me), isNull);
    });

    test('mute is read from your own row, not anyone else\'s', () {
      final r = room(participants: [
        participant(me, name: 'Me'),
        participant(peer, name: 'Sarah', muted: true),
      ]);
      expect(r.isMutedFor(me), isFalse);
    });

    test('the inviter is named only while the invite is pending', () {
      final pending = room(
        type: RoomType.group,
        name: 'Team',
        participants: [
          participant(me, status: 'pending', invitedByName: 'Sara Johnson'),
          participant(peer, name: 'Sarah'),
        ],
      );
      expect(pending.inviterNameFor(me), 'Sara Johnson');

      final joined = room(
        type: RoomType.group,
        name: 'Team',
        participants: [
          participant(me, invitedByName: 'Sara Johnson'),
          participant(peer, name: 'Sarah'),
        ],
      );
      expect(joined.inviterNameFor(me), isNull);
    });

    test('members sort admins first and pending last', () {
      final r = room(
        type: RoomType.group,
        name: 'Team',
        participants: [
          participant(me, name: 'Me'),
          participant('a', name: 'Zoe', status: 'pending'),
          participant('b', name: 'Devon'),
          participant('c', name: 'Ama', isAdmin: true),
        ],
      );
      expect(
        [for (final p in r.othersFor(me)) p.displayName],
        ['Ama', 'Devon', 'Zoe'],
      );
    });

    test('global rooms are no longer part of the inbox', () {
      expect(RoomType.global.isConversation, isFalse);
      expect(RoomType.direct.isConversation, isTrue);
      expect(RoomType.group.isConversation, isTrue);
    });
  });

  // ── Wire format ─────────────────────────────────────────────────────────

  group('parsing', () {
    test('a room carries its preview, photo and unread count', () {
      final parsed = ChatRoom.fromJson({
        'id': 'r1',
        'type': 'group',
        'name': 'Team Afropraise',
        'image_url': 'group.jpg',
        'created_at': now.toIso8601String(),
        'unread_count': 3,
        'participants': [],
        'last_message': {
          'id': 'm1',
          'sender_id': peer,
          'sender_name': 'Sarah',
          'content': 'hey',
          'has_image': false,
          'is_encrypted': false,
          'system_type': null,
          'created_at': now.toIso8601String(),
        },
      });

      expect(parsed.imageUrl, 'group.jpg');
      expect(parsed.unreadCount, 3);
      expect(parsed.lastMessage?.content, 'hey');
    });

    test('a room without a preview is null, not an empty one', () {
      final parsed = ChatRoom.fromJson({
        'id': 'r1',
        'type': 'direct',
        'created_at': now.toIso8601String(),
        'participants': [],
      });
      expect(parsed.lastMessage, isNull);
      expect(parsed.unreadCount, 0);
    });

    test('participants carry avatar, mute and inviter', () {
      final parsed = ChatParticipant.fromJson({
        'user_id': peer,
        'user_role': 'user',
        'user_name': 'Sarah',
        'user_image': 'sarah.jpg',
        'joined_at': now.toIso8601String(),
        'status': 'pending',
        'muted': true,
        'invited_by': me,
        'invited_by_name': 'Sara Johnson',
      });

      expect(parsed.userImage, 'sarah.jpg');
      expect(parsed.muted, isTrue);
      expect(parsed.invitedByName, 'Sara Johnson');
      expect(parsed.isPending, isTrue);
    });

    test('a message knows whether it is a system notice', () {
      ChatMessage parse(String? systemType) => ChatMessage.fromJson({
            'id': 'm1',
            'room_id': 'r1',
            'sender_id': peer,
            'sender_role': 'user',
            'created_at': now.toIso8601String(),
            'system_type': systemType,
          });

      expect(parse('invite_accepted').isSystem, isTrue);
      expect(parse(null).isSystem, isFalse);
      // Unrecognised types are not drawn, so they must not claim to be system
      // rows either — otherwise they render as an empty gap.
      expect(parse('from_the_future').isSystem, isFalse);
    });
  });
}
