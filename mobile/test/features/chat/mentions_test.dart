import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/presentation/mentions.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

ChatParticipant _p(String id, String name) => ChatParticipant(
      userId: id,
      userRole: 'user',
      userName: name,
      joinedAt: DateTime(2026, 8, 24),
    );

void main() {
  group('handles', () {
    test('are first name plus the initial of the second word', () {
      expect(Mentions.handleFor('Devon A'), 'devon_a');
      expect(Mentions.handleFor('Michael B D'), 'michael_b');
      expect(Mentions.handleFor('Sara Johnson'), 'sara_j');
    });

    test('a one-word name is the whole handle', () {
      expect(Mentions.handleFor('Kwame'), 'kwame');
    });

    test('punctuation and case never reach the handle', () {
      expect(Mentions.handleFor("O'Brien Máx"), 'o_b');
    });

    test('collisions are suffixed so every member is reachable', () {
      final handles = Mentions.handlesFor([
        _p('u1', 'Sara Johnson'),
        _p('u2', 'Sara Jones'),
        _p('u3', 'Sara Jenkins'),
      ]);
      expect(handles['u1'], 'sara_j');
      expect(handles['u2'], 'sara_j2');
      expect(handles['u3'], 'sara_j3');
    });
  });

  group('queryAt', () {
    test('finds the fragment the caret sits in', () {
      const text = "Let's ask @dev";
      final q = Mentions.queryAt(text, text.length);
      expect(q, isNotNull);
      expect(q!.query, 'dev');
      expect(q.start, text.indexOf('@'));
    });

    test('a bare @ offers everyone', () {
      const text = 'Hey @';
      expect(Mentions.queryAt(text, text.length)!.query, '');
    });

    test('is closed by the space after the handle', () {
      const text = '@devon_a thanks';
      expect(Mentions.queryAt(text, text.length), isNull);
    });

    test('an email address is not a mention', () {
      const text = 'mail me at sam@devon';
      expect(Mentions.queryAt(text, text.length), isNull);
    });
  });

  test('insert replaces the fragment and leaves the caret past the space', () {
    const text = "Let's ask @d";
    final q = Mentions.queryAt(text, text.length)!;
    final result = Mentions.insert(text, q, 'devon_a');
    expect(result.text, "Let's ask @devon_a ");
    expect(result.caret, result.text.length);
  });

  group('matches', () {
    final people = [
      _p('u1', 'Devon A'),
      _p('u2', 'Michael B D'),
      _p('u3', 'Sara Johnson'),
    ];
    final handles = Mentions.handlesFor(people);

    test('an empty query is the whole member list', () {
      expect(Mentions.matches(people, handles, '').length, 3);
    });

    test('matches on name or handle', () {
      expect(
        Mentions.matches(people, handles, 'mich').single.userId,
        'u2',
      );
      expect(
        Mentions.matches(people, handles, 'sara_j').single.userId,
        'u3',
      );
    });

    test('prefix matches rank above mid-word ones', () {
      final lisa = [_p('u4', 'Lisa Bell'), _p('u5', 'Sara Bell')];
      final h = Mentions.handlesFor(lisa);
      expect(Mentions.matches(lisa, h, 'sa').first.userId, 'u5');
    });
  });

  group('parse', () {
    final people = [_p('u1', 'Devon A'), _p('me', 'Kwame Owusu')];
    final handles = Mentions.handlesFor(people);
    final names = {for (final p in people) p.userId: p.displayName};

    test('a mention of the reader renders as @You', () {
      final spans = Mentions.parse(
        'Hey @kwame_o, can you bring the setup?',
        handles: handles,
        myUserId: 'me',
        displayNames: names,
      );
      final mention = spans.firstWhere((s) => s.isMention);
      expect(mention.text, '@You');
      expect(mention.isMe, isTrue);
      expect(spans.map((s) => s.text).join(),
          'Hey @You, can you bring the setup?');
    });

    test('a mention of someone else renders as their first name', () {
      final spans = Mentions.parse(
        'ask @devon_a',
        handles: handles,
        myUserId: 'me',
        displayNames: names,
      );
      expect(spans.firstWhere((s) => s.isMention).text, '@Devon');
    });

    test('an @word matching nobody stays plain text', () {
      final spans = Mentions.parse(
        'ping @nobody about it',
        handles: handles,
        myUserId: 'me',
        displayNames: names,
      );
      expect(spans.any((s) => s.isMention), isFalse);
      expect(spans.single.text, 'ping @nobody about it');
    });

    test('several mentions in one message are all found', () {
      final spans = Mentions.parse(
        '@devon_a and @kwame_o',
        handles: handles,
        myUserId: 'me',
        displayNames: names,
      );
      expect(spans.where((s) => s.isMention).length, 2);
    });
  });

  test('mentions() reports whether a message names a given user', () {
    final people = [_p('u1', 'Devon A'), _p('me', 'Kwame Owusu')];
    final handles = Mentions.handlesFor(people);
    expect(
      Mentions.mentions('hi @kwame_o', userId: 'me', handles: handles),
      isTrue,
    );
    expect(
      Mentions.mentions('hi @devon_a', userId: 'me', handles: handles),
      isFalse,
    );
  });
}
