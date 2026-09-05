import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/celebration/comment_milestone.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// The Found tab's comment badge, which never moved.
///
/// A photo's comments and an event's comments are messages in that thing's chat
/// room, so they arrive on the socket rather than on an HTTP response — and the
/// socket path reported the *milestone* but never the count. The confetti fired
/// and the badge sat still.
///
/// The blocs that did report a count are a different path: FeedCommentBloc
/// serves ads, requests and campaigns, and PhotoCommentBloc is registered in the
/// service locator but wired to no screen at all — the photo sheet runs on
/// ChatRoomBloc like the event sheet does.
///
/// These pin the reporting rule the bloc now follows, without standing up a
/// socket: who gets the badge, who gets the confetti, and what is keyed by
/// what. The `_onReceived` guard under test is
///
///     final targetId = state.room?.eventId;
///     if (targetId != null && targetId.isNotEmpty) report(targetId, count);
///     if (msg.senderId == me) milestone(count);
///
/// and the fixtures below feed it the same shapes the server sends.
ChatMessage message({
  required String senderId,
  int? targetCommentCount,
}) =>
    ChatMessage(
      id: 'm1',
      roomId: 'room-1',
      senderId: senderId,
      senderRole: 'user',
      content: 'nice one',
      createdAt: DateTime.now(),
      targetCommentCount: targetCommentCount,
    );

/// A photo room. `eventId` carries the *picture* id here — the server keys a
/// photo room the same way it keys an event room, which is what lets one field
/// answer for both.
ChatRoom room(String targetId) => ChatRoom(
      id: 'room-1',
      type: RoomType.photo,
      eventId: targetId,
      createdAt: DateTime.now(),
    );

/// The bloc's rule, applied. Kept beside the tests rather than reaching into a
/// live bloc: standing one up needs a socket, a token and a room join, none of
/// which is the thing that was broken.
void applyIncoming({
  required ChatMessage msg,
  required ChatRoom? currentRoom,
  required String myUserId,
}) {
  final landedAt = msg.targetCommentCount;
  if (landedAt == null) return;

  final targetId = currentRoom?.eventId;
  if (targetId != null && targetId.isNotEmpty) {
    CommentCounts.instance.report(targetId, landedAt);
  }
  if (msg.senderId == myUserId) {
    CommentMilestones.instance.report(landedAt);
  }
}

void main() {
  setUp(() {
    CommentCounts.instance.clear();
    CommentMilestones.instance.consume();
  });

  test('my own comment moves the badge', () {
    // The case in the bug report: comment on a found photo, watch the count
    // stay where it was.
    applyIncoming(
      msg: message(senderId: 'me', targetCommentCount: 4),
      currentRoom: room('pic-1'),
      myUserId: 'me',
    );

    expect(CommentCounts.instance.countFor('pic-1'), 4);
  });

  test('somebody else\'s comment moves it too', () {
    // The badge is a fact about the photo, not about who typed. A reader
    // watching a thread should see it climb as comments arrive.
    applyIncoming(
      msg: message(senderId: 'them', targetCommentCount: 9),
      currentRoom: room('pic-1'),
      myUserId: 'me',
    );

    expect(CommentCounts.instance.countFor('pic-1'), 9);
  });

  test('the confetti is the author\'s alone', () {
    applyIncoming(
      msg: message(senderId: 'them', targetCommentCount: 100),
      currentRoom: room('pic-1'),
      myUserId: 'me',
    );

    // Their milestone, not mine — but the count still moved.
    expect(CommentMilestones.instance.pending.value, isNull);
    expect(CommentCounts.instance.countFor('pic-1'), 100);

    applyIncoming(
      msg: message(senderId: 'me', targetCommentCount: 100),
      currentRoom: room('pic-1'),
      myUserId: 'me',
    );

    expect(CommentMilestones.instance.pending.value, isNotNull);
  });

  test('a reply moves nothing', () {
    // Replies do not count towards the badge, so the server sends null and
    // both readers stay quiet — including the badge, which must keep whatever
    // it was showing rather than being blanked.
    CommentCounts.instance.report('pic-1', 7);

    applyIncoming(
      msg: message(senderId: 'me'),
      currentRoom: room('pic-1'),
      myUserId: 'me',
    );

    expect(CommentCounts.instance.countFor('pic-1'), 7);
    expect(CommentMilestones.instance.pending.value, isNull);
  });

  test('a room with no target reports nothing rather than guessing', () {
    // A direct message has no picture or event behind it. Reporting under an
    // empty key would put a count on a target that does not exist.
    applyIncoming(
      msg: message(senderId: 'me', targetCommentCount: 3),
      currentRoom: room(''),
      myUserId: 'me',
    );

    expect(CommentCounts.instance.countFor(''), isNull);
  });
}
