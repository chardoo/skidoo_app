import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/models/photo_comment/photo_comment.dart';

void main() {
  group('PhotoComment.fromJson', () {
    test('parses fields and coerces non-string values via toString', () {
      final c = PhotoComment.fromJson({
        'id': 123,
        'picture_id': 'pic1',
        'user_id': 'u1',
        'user_name': 'Ama',
        'user_role': 'user',
        'content': 'nice shot',
        'parent_id': null,
        'reply_count': 4,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(c.id, '123');
      expect(c.pictureId, 'pic1');
      expect(c.content, 'nice shot');
      expect(c.parentId, isNull);
      expect(c.replyCount, 4);
      expect(c.createdAt, DateTime.parse('2026-01-01T00:00:00Z'));
    });

    test('defaults missing fields safely', () {
      final c = PhotoComment.fromJson({});
      expect(c.id, '');
      expect(c.pictureId, '');
      expect(c.userName, '');
      expect(c.replyCount, 0);
      expect(c.createdAt, isA<DateTime>());
    });

    test('falls back to now() on an unparseable date', () {
      final before = DateTime.now();
      final c = PhotoComment.fromJson({'created_at': 'not-a-date'});
      expect(c.createdAt.isAfter(before.subtract(const Duration(seconds: 5))), isTrue);
    });
  });

  test('copyWith overrides only the given fields', () {
    final c = PhotoComment(
      id: '1',
      pictureId: 'p',
      userId: 'u',
      userName: 'Ama',
      userRole: 'user',
      content: 'hi',
      replyCount: 0,
      createdAt: DateTime(2026, 1, 1),
    );
    final updated = c.copyWith(content: 'edited', replyCount: 2);
    expect(updated.content, 'edited');
    expect(updated.replyCount, 2);
    expect(updated.userName, 'Ama');
    expect(updated.id, '1');
  });
}
