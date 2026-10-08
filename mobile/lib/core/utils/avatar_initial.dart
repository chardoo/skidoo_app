/// The letter an avatar shows when there is no photograph to show.
///
/// Every avatar in the app used to write its own version of
/// `name.isNotEmpty ? name[0].toUpperCase() : '?'`, in two dozen places, and
/// the empty branch is wrong in all of them. A question mark says the app does
/// not know who this is — which is both unfriendly and usually untrue: the
/// name is on its way, or it is somewhere else on the record, or this is the
/// person's own avatar and they certainly know who they are. It reads as an
/// error where there is no error.
///
/// So this never answers with a question mark. It takes the candidates in the
/// order they are worth trying and returns the first letter it can find in
/// any of them; when they are all empty it answers [kJpergInitial].
///
/// ```dart
/// avatarInitial(user.name)                       // a name
/// avatarInitial(user.name, user.username)        // or whatever else is known
/// ```
library;

/// What an avatar falls back to when nothing at all is known.
///
/// The app's own letter, so an avatar with nothing behind it still belongs to
/// something. Better than a question mark, which announces a gap.
const String kJpergInitial = 'J';

/// The first letter or digit in [first], else in [second], else in [third] —
/// uppercased — or [kJpergInitial] when none of them has one.
///
/// Leading punctuation, spaces and emoji are stepped over rather than drawn:
/// a studio called "@kwame" wants a K, and "🎉 Afrobeats" wants an A. A name
/// that is *only* an emoji falls through to the next candidate rather than
/// rendering a glyph that will not fit a circle.
///
/// Walks graphemes, not code units. `name[0]` on a name beginning with an
/// emoji or any other astral character takes half a surrogate pair and draws
/// the replacement box.
String avatarInitial(String? first, [String? second, String? third]) {
  for (final candidate in [first, second, third]) {
    final letter = _firstLetterOf(candidate);
    if (letter != null) return letter;
  }
  return kJpergInitial;
}

/// The first alphanumeric grapheme in [value], uppercased, or null.
String? _firstLetterOf(String? value) {
  if (value == null) return null;
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (_isLetterOrDigit(char)) return char.toUpperCase();
  }
  return null;
}

/// Whether [char] is something worth drawing in a circle.
///
/// Deliberately not ASCII-only: Ghanaian names carry Ɛ and Ɔ, and plenty of
/// people here write their names in scripts that have no ASCII at all. The
/// test is "does this have a case or is it a digit", which every alphabet
/// answers and punctuation, whitespace and emoji do not.
bool _isLetterOrDigit(String char) {
  if (RegExp(r'[0-9]').hasMatch(char)) return true;
  // A letter is a character that is not punctuation, whitespace or a symbol.
  // Checking the categories directly is not available in Dart's core regexp
  // without unicode property escapes, which it does support.
  return RegExp(r'\p{L}', unicode: true).hasMatch(char);
}
