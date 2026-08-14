import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// The bug these lock down: accepting a group invite changed the server and
/// nothing else. The invited room is written to SQLite the moment the invite
/// arrives over the socket, with the invitee marked `pending` — and the rooms
/// list reads that cache *before* it syncs. So the optimistic move into the
/// active list was undone one frame later by `hasPendingInvite` reading the
/// stale row, and the group vanished until the server round-trip landed. On a
/// warm `/chat/rooms` cache it did not come back at all.
void main() {
  const me = 'me-1';
  const other = 'other-1';

  ChatParticipant participant(String userId, {String status = 'active'}) =>
      ChatParticipant(
        userId: userId,
        userRole: 'user',
        joinedAt: DateTime(2026, 8, 14),
        status: status,
      );

  ChatRoom roomWith(List<ChatParticipant> participants) => ChatRoom(
        id: 'room-1',
        type: RoomType.group,
        createdAt: DateTime(2026, 8, 14),
        participants: participants,
      );

  test('accepting clears the pending invite the rooms list splits on', () {
    final invited = roomWith([
      participant(other),
      participant(me, status: 'pending'),
    ]);
    expect(invited.hasPendingInvite(me), isTrue);

    final accepted = invited.withInviteAccepted(me)!;

    expect(accepted.hasPendingInvite(me), isFalse,
        reason: 'this is what _splitRooms reads — while it answers true the '
            'room goes back into the pending bucket on every load');
  });

  test('only the accepting user moves', () {
    final invited = roomWith([
      participant(other, status: 'pending'),
      participant(me, status: 'pending'),
    ]);

    final accepted = invited.withInviteAccepted(me)!;

    expect(accepted.hasPendingInvite(me), isFalse);
    expect(accepted.hasPendingInvite(other), isTrue,
        reason: 'someone else\'s invite is not mine to accept');
  });

  test('everything else about the room survives the flip', () {
    final invited = roomWith([
      participant(other),
      participant(me, status: 'pending'),
    ]);

    final accepted = invited.withInviteAccepted(me)!;

    expect(accepted.id, invited.id);
    expect(accepted.type, invited.type);
    expect(accepted.createdAt, invited.createdAt);
    expect(accepted.participants, hasLength(2));
    // The other participant is untouched, name and role included.
    final kept = accepted.participants.firstWhere((p) => p.userId == other);
    expect(kept.userRole, 'user');
    expect(kept.status, 'active');
  });

  test('nothing to accept returns null, so no pointless write', () {
    // Already a member — the common case when a reload races the join.
    final joined = roomWith([participant(other), participant(me)]);
    expect(joined.withInviteAccepted(me), isNull);

    // Not in the room at all.
    final stranger = roomWith([participant(other)]);
    expect(stranger.withInviteAccepted(me), isNull);
  });

  test('survives the JSON round trip the cache stores it as', () {
    // chat_rooms.participants is a JSON blob, so the flip only sticks if the
    // status is carried through toJson/fromJson.
    final accepted = roomWith([
      participant(other),
      participant(me, status: 'pending'),
    ]).withInviteAccepted(me)!;

    final reread = accepted.participants
        .map((p) => ChatParticipant.fromJson(p.toJson()))
        .toList();

    expect(reread.firstWhere((p) => p.userId == me).isPending, isFalse);
  });
}
