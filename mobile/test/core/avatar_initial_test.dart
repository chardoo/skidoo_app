import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/utils/avatar_initial.dart';

void main() {
  group('it takes the first letter', () {
    test('of a name', () => expect(avatarInitial('Kwame'), 'K'));
    test('uppercased', () => expect(avatarInitial('kwame'), 'K'));
    test('of the first word', () => expect(avatarInitial('Ama Serwaa'), 'A'));
  });

  group('it never answers with a question mark', () {
    for (final empty in <String?>[null, '', '   ', '...', '@', '🎉', '—']) {
      test('for ${empty == null ? 'null' : '"$empty"'}', () {
        expect(avatarInitial(empty), kJpergInitial);
      });
    }
  });

  group('it steps over what will not fit a circle', () {
    test('leading punctuation', () => expect(avatarInitial('@kwame'), 'K'));
    test('leading space', () => expect(avatarInitial('  Ama'), 'A'));
    test('a leading emoji', () => expect(avatarInitial('🎉 Afrobeats'), 'A'));
  });

  group('it reads names the way they are written here', () {
    test('Ghanaian letters', () => expect(avatarInitial('Ɛdwuma'), 'Ɛ'));
    test('other scripts', () => expect(avatarInitial('Адам'), 'А'));
    test('a digit is a letter enough', () => expect(avatarInitial('99 Studio'), '9'));
  });

  group('it tries everything it was given', () {
    test('the second when the first is empty',
        () => expect(avatarInitial('', 'kwame_shoots'), 'K'));
    test('the third when both are empty',
        () => expect(avatarInitial(null, '  ', 'ama@example.com'), 'A'));
    test('and gives up on jperg',
        () => expect(avatarInitial('', '', ''), kJpergInitial));
  });

  test('it never returns more than one character', () {
    for (final name in ['Kwame', '🎉 Afrobeats', '', 'Ɛdwuma', '99']) {
      expect(avatarInitial(name).runes.length, 1, reason: name);
    }
  });

  group('no avatar still draws a question mark', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    test('nowhere in the app', () {
      // Nineteen places each wrote their own
      // `name.isNotEmpty ? name[0].toUpperCase() : '?'`, and the empty branch
      // was wrong in all of them: a question mark says the app does not know
      // who this is, which is unfriendly and usually untrue — the name is on
      // its way, or it is somewhere else on the record, or it is the viewer's
      // own avatar and they know perfectly well who they are.
      final offenders = <String>[];
      for (final file in dartFiles) {
        if (file.path.endsWith('core/utils/avatar_initial.dart')) continue;
        final code = file
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        // `split('?')` and `indexOf('?')` are URL work, not avatars.
        if (RegExp(r":\s*'\?'").hasMatch(code)) offenders.add(file.path);
      }
      expect(offenders, isEmpty,
          reason: 'use avatarInitial(), which falls through to J');
    });

    test('and nobody hand-rolls an avatar letter any more', () {
      // `name[0]` takes a UTF-16 code unit, so a name beginning with an emoji
      // or any astral character draws half a surrogate pair — the replacement
      // box. Worse, six of these had no empty check at all: `name[0]` on ''
      // throws a RangeError and takes the widget down with it.
      //
      // Not every `[0].toUpperCase()` though. The ones followed by
      // `+ …substring(1)` are capitalising a whole word — a role, an audience
      // — which is a different job and reads fine as it is.
      final offenders = <String>[];
      final initial = RegExp(r'\[0\]\.toUpperCase\(\)(?!\s*\+)');
      for (final file in dartFiles) {
        if (file.path.endsWith('core/utils/avatar_initial.dart')) continue;
        final code = file
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (initial.hasMatch(code)) offenders.add(file.path);
      }
      expect(offenders, isEmpty, reason: 'use avatarInitial()');
    });

    test('an empty name cannot throw', () {
      // The crash the six unguarded ones would have caused.
      expect(() => avatarInitial(''), returnsNormally);
      expect(avatarInitial(''), kJpergInitial);
    });

    test('the shared avatar derives its own letter', () {
      // Several screens used to pre-compute '?' and hand *that* in as the
      // name, so UserAvatar faithfully drew the first character of "?".
      final source =
          File('lib/core/common/widgets/user_avatar.dart').readAsStringSync();
      expect(source, contains('avatarInitial(initial)'));
    });
  });
}
