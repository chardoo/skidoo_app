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
}
