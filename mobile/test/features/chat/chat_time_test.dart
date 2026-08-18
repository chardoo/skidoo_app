import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/utils/server_time.dart';
import 'package:jperg_app/features/chat/presentation/chat_time.dart';
import 'package:jperg_app/features/chat/presentation/widgets/day_separator.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// The server's rendering of [local] — the same instant, expressed in UTC, as
/// it would come back over the wire.
String asServerSends(DateTime local) => local.toUtc().toIso8601String();

void main() {
  group('parseServerTime', () {
    test('a Z-suffixed timestamp is read as UTC', () {
      final t = parseServerTime('2026-08-18T10:23:45.000Z');
      expect(t.isUtc, isTrue);
      expect(t.hour, 10);
    });

    test('an explicit offset is honoured, not ignored', () {
      // 11:23 at +01:00 is 10:23 UTC.
      final t = parseServerTime('2026-08-18T11:23:45.000+01:00');
      expect(t.isUtc, isTrue);
      expect(t.hour, 10);
    });

    test('a timestamp with no zone at all is UTC, not local', () {
      // This is the one DateTime.parse gets wrong: with nothing to go on it
      // assumes the reader's own timezone, so the same message would be a
      // different time on a phone in Accra and a phone in Lagos.
      final t = parseServerTime('2026-08-18T10:23:45.000000');
      expect(t.isUtc, isTrue);
      expect(t.hour, 10);
    });

    test('surrounding whitespace does not change the answer', () {
      expect(
        parseServerTime('  2026-08-18T10:23:45Z  '),
        parseServerTime('2026-08-18T10:23:45Z'),
      );
    });
  });

  group('ChatTime shows the phone clock, not the server clock', () {
    test('a message bubble shows the local hour and minute', () {
      final onThePhone = DateTime(2026, 8, 18, 14, 3);
      expect(ChatTime.clock(parseServerTime(asServerSends(onThePhone))),
          '14:03');
    });

    test('midnight and noon read correctly on the 12-hour inbox clock', () {
      expect(
        ChatTime.clock12(parseServerTime(asServerSends(DateTime(2026, 8, 18, 0, 5)))),
        '12:05 am',
      );
      expect(
        ChatTime.clock12(parseServerTime(asServerSends(DateTime(2026, 8, 18, 12, 5)))),
        '12:05 pm',
      );
      expect(
        ChatTime.clock12(parseServerTime(asServerSends(DateTime(2026, 8, 18, 13, 7)))),
        '1:07 pm',
      );
    });

    test('"today" is the phone\'s today, right up to local midnight', () {
      final now = DateTime.now();
      final justBeforeLocalMidnight =
          DateTime(now.year, now.month, now.day, 23, 59);
      expect(
        ChatTime.daysAgo(parseServerTime(asServerSends(justBeforeLocalMidnight))),
        0,
      );

      final justAfterLocalMidnight = DateTime(now.year, now.month, now.day, 0, 1);
      expect(
        ChatTime.daysAgo(parseServerTime(asServerSends(justAfterLocalMidnight))),
        0,
      );
    });

    test('yesterday is one local day back', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day, 12).subtract(
        const Duration(days: 1),
      );
      expect(ChatTime.daysAgo(parseServerTime(asServerSends(yesterday))), 1);
    });

    test('two messages either side of local midnight are different days', () {
      final base = DateTime(2026, 8, 18, 23, 59);
      final justAfter = DateTime(2026, 8, 19, 0, 1);
      expect(
        ChatTime.sameDay(
          parseServerTime(asServerSends(base)),
          parseServerTime(asServerSends(justAfter)),
        ),
        isFalse,
      );
    });

    test('two messages within the same local day are the same day', () {
      expect(
        ChatTime.sameDay(
          parseServerTime(asServerSends(DateTime(2026, 8, 18, 0, 1))),
          parseServerTime(asServerSends(DateTime(2026, 8, 18, 23, 59))),
        ),
        isTrue,
      );
    });

    test('short and long dates use local calendar fields', () {
      final t = parseServerTime(asServerSends(DateTime(2026, 8, 5, 9, 30)));
      expect(ChatTime.shortDate(t), '05/08/2026');
      expect(ChatTime.longDate(t), contains('5 Aug'));
    });
  });

  group('DaySeparator follows the phone', () {
    test('a message from a few minutes ago is filed under Today', () {
      final t = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      expect(DaySeparator.label(t), 'Today');
    });

    test('a separator is needed across a local midnight', () {
      expect(
        DaySeparator.needsSeparator(
          parseServerTime(asServerSends(DateTime(2026, 8, 18, 23, 50))),
          parseServerTime(asServerSends(DateTime(2026, 8, 19, 0, 10))),
        ),
        isTrue,
      );
    });

    test('no separator between two messages on the same local day', () {
      expect(
        DaySeparator.needsSeparator(
          parseServerTime(asServerSends(DateTime(2026, 8, 18, 1, 0))),
          parseServerTime(asServerSends(DateTime(2026, 8, 18, 22, 0))),
        ),
        isFalse,
      );
    });
  });

  group('messages round-trip through the cache without drifting', () {
    test('a message parsed from the server serialises back as the same instant',
        () {
      final json = {
        'id': 'm1',
        'room_id': 'r1',
        'sender_id': 'u1',
        'sender_role': 'user',
        'content': 'hello',
        'created_at': '2026-08-18T10:23:45.000Z',
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.createdAt.isUtc, isTrue);

      // What the local cache writes into its text created_at column. It must
      // be UTC for every row, because SQL orders that column as a string.
      final written = msg.toJson()['created_at'] as String;
      expect(written.endsWith('Z'), isTrue);
      expect(DateTime.parse(written).toUtc(), msg.createdAt);
    });
  });
}
