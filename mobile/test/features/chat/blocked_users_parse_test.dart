import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart';

/// The block list is what every piece of block UI is driven from: whether
/// Contact Info says Block or Unblock, and whether the composer is replaced by
/// the blocked banner. Parsing it into an empty list does not look like a
/// failure from the outside — it looks exactly like "nobody is blocked", which
/// is why this went unnoticed. So the shape the server actually sends is
/// pinned here.
void main() {
  group('parseBlockedUsers', () {
    test('reads the envelope the server sends', () {
      expect(
        parseBlockedUsers({
          'data': ['user-1', 'user-2'],
          'blocked_users': ['user-1', 'user-2'],
        }),
        ['user-1', 'user-2'],
      );
    });

    test('reads an envelope that only carries the legacy key', () {
      expect(
        parseBlockedUsers({
          'blocked_users': ['user-1'],
        }),
        ['user-1'],
      );
    });

    test('an empty block list is empty, not an error', () {
      expect(parseBlockedUsers({'data': <dynamic>[]}), isEmpty);
    });

    test('accepts a bare list of ids', () {
      expect(parseBlockedUsers(['user-1', 'user-2']), ['user-1', 'user-2']);
    });

    test('accepts a bare list of objects', () {
      expect(
        parseBlockedUsers([
          {'blocked_id': 'user-1'},
          {'id': 'user-2'},
        ]),
        ['user-1', 'user-2'],
      );
    });

    test('drops blanks and nulls rather than emitting empty ids', () {
      expect(
        parseBlockedUsers([
          'user-1',
          '',
          null,
          {'blocked_id': null},
        ]),
        ['user-1'],
      );
    });

    test('an unexpected body yields an empty list instead of throwing', () {
      expect(parseBlockedUsers(null), isEmpty);
      expect(parseBlockedUsers('nope'), isEmpty);
      expect(parseBlockedUsers({'data': 'nope'}), isEmpty);
    });
  });

  group('CanMessageResult block directions', () {
    test('separates a block we made from one made against us', () {
      final mine = CanMessageResult.fromJson({
        'can_message': false,
        'reason': 'USER_BLOCKED',
        'blocked_by_me': true,
        'blocked_by_them': false,
      });
      expect(mine.blockedByMe, isTrue);
      expect(mine.blockedByThem, isFalse);

      final theirs = CanMessageResult.fromJson({
        'can_message': false,
        'reason': 'USER_BLOCKED',
        'blocked_by_me': false,
        'blocked_by_them': true,
      });
      // Same reason code, opposite UI: theirs must not offer an Unblock action.
      expect(theirs.reason, 'USER_BLOCKED');
      expect(theirs.blockedByMe, isFalse);
      expect(theirs.blockedByThem, isTrue);
    });

    test('an older server that omits the flags reads as not blocked', () {
      final r = CanMessageResult.fromJson({'can_message': true});
      expect(r.blockedByMe, isFalse);
      expect(r.blockedByThem, isFalse);
    });
  });
}
