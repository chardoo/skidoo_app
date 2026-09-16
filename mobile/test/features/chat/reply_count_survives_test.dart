import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// A comment has to carry how many replies hang off it.
///
/// A comment room's history is top-level only — chat's rooms.py filters
/// `parent_id IS NULL` — so the replies never arrive with it. The sheet used to
/// build its reply map out of that same filtered list and read the *length* of
/// it, which is necessarily zero: every comment reported no replies, the
/// toggle that fetches them never appeared, and the replies could not be
/// reached from the sheet by any action at all.
///
/// So the number comes from the server, and it has to survive every layer it
/// passes through — the wire, the cache, and a copyWith.
void main() {
  Map<String, dynamic> json({int? replyCount}) => {
        'id': 'c1',
        'room_id': 'r1',
        'sender_id': 'u1',
        'sender_name': 'Ama',
        'sender_role': 'user',
        'content': 'the light in the third one is unreal',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        if (replyCount != null) 'reply_count': replyCount,
      };

  test('it is read off the wire', () {
    expect(ChatMessage.fromJson(json(replyCount: 3)).replyCount, 3);
  });

  test('a message with no thread carries zero, not null', () {
    // A chat message is not a comment and has no thread under it. Zero is the
    // honest answer and keeps the row from having to handle a missing value.
    expect(ChatMessage.fromJson(json()).replyCount, 0);
  });

  test('it survives the round trip the local cache makes', () {
    // The sheet paints from SQLite first, so a count dropped here means a
    // cached comment offers no way into its thread until a refetch.
    final original = ChatMessage.fromJson(json(replyCount: 5));

    expect(ChatMessage.fromJson(original.toJson()).replyCount, 5);
  });

  test('copyWith does not drop it', () {
    // The bloc rebuilds messages through copyWith on every like settle.
    final message = ChatMessage.fromJson(json(replyCount: 4));

    expect(message.copyWith(likeCount: 9).replyCount, 4);
  });
}
