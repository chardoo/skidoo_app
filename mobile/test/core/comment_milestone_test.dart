import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/celebration/comment_milestone.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// Which comments are worth a celebration, and which are just comments.
///
/// The rule is the product decision here, so it is the thing pinned: first,
/// then each power of ten from a hundred. Everything in between passes without
/// interruption, which is almost every comment ever posted.
void main() {
  group('which counts are milestones', () {
    test('the first comment is', () {
      expect(isCommentMilestone(1), isTrue);
    });

    test('the powers of ten from a hundred up are', () {
      for (final n in [100, 1000, 10000, 100000, 1000000]) {
        expect(isCommentMilestone(n), isTrue, reason: '$n should count');
      }
    });

    test('ten is not — they are meant to be rare', () {
      // A milestone every tenth comment is a notification that means nothing
      // by the third time somebody sees it.
      expect(isCommentMilestone(10), isFalse);
    });

    test('the ordinary run of comments is not', () {
      for (final n in [2, 3, 9, 11, 50, 99, 101, 150, 999, 1001, 12000]) {
        expect(isCommentMilestone(n), isFalse, reason: '$n should not count');
      }
    });
  });

  group('what it says', () {
    test('being first is an achievement, not a position', () {
      expect(commentMilestoneMessage(1), "You're the first to comment 🎉");
    });

    test('everything after it is a position', () {
      expect(commentMilestoneMessage(100), 'You are the 100th comment 🎉');
      expect(commentMilestoneMessage(1000), 'You are the 1,000th comment 🎉');
      expect(
        commentMilestoneMessage(1000000),
        'You are the 1,000,000th comment 🎉',
      );
    });

    test('an ordinary comment says nothing at all', () {
      expect(commentMilestoneMessage(2), isNull);
      expect(commentMilestoneMessage(99), isNull);
      expect(commentMilestoneMessage(101), isNull);
    });

    test('a reply says nothing — the server sends null for one', () {
      // Replies do not move the count, so there is no position to report and
      // no milestone to reach.
      expect(commentMilestoneMessage(null), isNull);
    });

    test('a nonsense count says nothing rather than guessing', () {
      expect(commentMilestoneMessage(0), isNull);
      expect(commentMilestoneMessage(-5), isNull);
    });
  });

  group('the ordinal', () {
    // General on purpose: the milestones may move, and an ordinal that only
    // handles today's is a trap for whoever moves them.
    test('handles the awkward teens', () {
      expect(ordinal(11), '11th');
      expect(ordinal(12), '12th');
      expect(ordinal(13), '13th');
      expect(ordinal(111), '111th');
    });

    test('handles the ordinary endings', () {
      expect(ordinal(1), '1st');
      expect(ordinal(2), '2nd');
      expect(ordinal(3), '3rd');
      expect(ordinal(4), '4th');
      expect(ordinal(21), '21st');
      expect(ordinal(102), '102nd');
    });

    test('groups the digits', () {
      expect(groupDigits(1), '1');
      expect(groupDigits(100), '100');
      expect(groupDigits(1000), '1,000');
      expect(groupDigits(1234567), '1,234,567');
    });
  });

  group('the message that carries it', () {
    // The bug this was found by: photo and event comments are *chat messages*,
    // not comment-API rows, so the count has to survive ChatMessage.fromJson or
    // the celebration never fires on the two surfaces people actually use.
    ChatMessage parse(Map<String, dynamic> extra) => ChatMessage.fromJson({
          'id': 'm1',
          'room_id': 'r1',
          'sender_id': 'u1',
          'sender_name': 'Ama',
          'sender_role': 'user',
          'content': 'first!',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          ...extra,
        });

    test('a top-level comment carries where it landed', () {
      expect(parse({'target_comment_count': 100}).targetCommentCount, 100);
    });

    test('a reply carries nothing — it moved no count', () {
      expect(parse({'target_comment_count': null}).targetCommentCount, isNull);
    });

    test('an older server that sends no count at all is not an error', () {
      expect(parse({}).targetCommentCount, isNull);
    });
  });

  group('the signal', () {
    tearDown(CommentMilestones.instance.consume);

    test('holds a milestone for whoever is watching', () {
      CommentMilestones.instance.report(100);

      expect(CommentMilestones.instance.pending.value,
          'You are the 100th comment 🎉');
    });

    test('stays quiet for an ordinary comment', () {
      CommentMilestones.instance.report(42);

      expect(CommentMilestones.instance.pending.value, isNull);
    });

    test('is cleared once shown, so nothing celebrates twice', () {
      CommentMilestones.instance.report(1);
      CommentMilestones.instance.consume();

      expect(CommentMilestones.instance.pending.value, isNull);
    });
  });
}
