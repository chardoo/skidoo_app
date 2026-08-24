import 'package:jperg_app/models/chat/chat_room.dart';

/// Everything the app knows about `@mentions` in a conversation.
///
/// Mentions travel inside the message text as `@handle` — no markup, no
/// side-channel. That is a deliberate constraint: the message body is the only
/// field that is end-to-end encrypted in a DM, so anything carried beside it
/// would be readable by the server, and anything that isn't plain text would
/// arrive as gibberish in a client that doesn't know the convention (the web
/// panel, a push notification preview, an older build). Plain `@devon_a`
/// degrades to exactly what it says.
///
/// A handle is derived from the display name rather than stored, because the
/// chat service has no usernames — only the denormalised `user_name` on each
/// participant row.
class Mentions {
  const Mentions._();

  /// The token the composer inserts and the renderer looks for.
  ///
  /// "Devon A" → `devon_a`, "Michael B D" → `michael_b`, "Sara" → `sara`.
  /// Only the first two words are used: a third would make the handle longer
  /// than the name it stands for, and the picker is what disambiguates anyway.
  static String handleFor(String displayName) {
    final words = displayName
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words.first;
    return '${words.first}_${words[1][0]}';
  }

  /// Handles are not guaranteed unique — two "Sara J"s collide. Suffix the
  /// duplicates so each participant still has a token that resolves to them.
  ///
  /// Returns {userId: handle}. Order follows [participants], so the same list
  /// always produces the same assignment.
  static Map<String, String> handlesFor(Iterable<ChatParticipant> participants) {
    final result = <String, String>{};
    final used = <String>{};
    for (final p in participants) {
      var handle = handleFor(p.displayName);
      if (handle.isEmpty) continue;
      if (used.contains(handle)) {
        var n = 2;
        while (used.contains('$handle$n')) {
          n++;
        }
        handle = '$handle$n';
      }
      used.add(handle);
      result[p.userId] = handle;
    }
    return result;
  }

  /// Matches an `@handle` anywhere in a message.
  ///
  /// The leading `(?<![A-Za-z0-9_])` keeps an email address from being read as
  /// a mention of its domain — "mail@devon_a" is not a mention.
  static final RegExp tokenPattern =
      RegExp(r'(?<![A-Za-z0-9_])@([a-z0-9_]+)', caseSensitive: false);

  /// The `@…` fragment the caret currently sits inside, or null when the user
  /// is not typing a mention.
  ///
  /// Returns the fragment *without* the `@`, so an empty string means the user
  /// has just typed `@` and every member should be offered.
  static MentionQuery? queryAt(String text, int caretOffset) {
    if (caretOffset < 0 || caretOffset > text.length) return null;
    // Walk back from the caret to the nearest '@', giving up at whitespace —
    // a mention is one word, so anything else means we are past it.
    var i = caretOffset - 1;
    while (i >= 0) {
      final ch = text[i];
      if (ch == '@') {
        // '@' only opens a mention at the start of a word; "a@b" is not one.
        if (i > 0 && RegExp(r'[A-Za-z0-9_]').hasMatch(text[i - 1])) return null;
        return MentionQuery(
          start: i,
          end: caretOffset,
          query: text.substring(i + 1, caretOffset),
        );
      }
      if (RegExp(r'\s').hasMatch(ch)) return null;
      i--;
    }
    return null;
  }

  /// [text] with the mention fragment at [query] replaced by `@handle `.
  /// The trailing space is what closes the mention, so the picker doesn't
  /// immediately reopen on the token that was just inserted.
  static ReplacementResult insert(
    String text,
    MentionQuery query,
    String handle,
  ) {
    final replacement = '@$handle ';
    return ReplacementResult(
      text: text.replaceRange(query.start, query.end, replacement),
      caret: query.start + replacement.length,
    );
  }

  /// Participants whose name or handle matches [query], best matches first.
  ///
  /// An empty [query] returns everyone — that is the state right after typing
  /// `@`, where the picker is a member list rather than a search result.
  static List<ChatParticipant> matches(
    Iterable<ChatParticipant> participants,
    Map<String, String> handles,
    String query,
  ) {
    final q = query.toLowerCase();
    final candidates = [
      for (final p in participants)
        if (handles.containsKey(p.userId)) p,
    ];
    if (q.isEmpty) return candidates;
    return [
      for (final p in candidates)
        if (p.displayName.toLowerCase().contains(q) ||
            handles[p.userId]!.contains(q))
          p,
    ]..sort((a, b) {
        // Prefix matches before mid-word ones, so typing "sa" puts "Sara"
        // above "Lisa".
        final aStarts = handles[a.userId]!.startsWith(q) ||
            a.displayName.toLowerCase().startsWith(q);
        final bStarts = handles[b.userId]!.startsWith(q) ||
            b.displayName.toLowerCase().startsWith(q);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
  }

  /// Split [text] into runs, marking the ones that are mentions of a known
  /// participant. Everything else comes back as plain text — an `@word` that
  /// matches nobody is not styled, because highlighting it would promise a
  /// person who isn't in the room.
  static List<MentionSpan> parse(
    String text, {
    required Map<String, String> handles,
    required String myUserId,
    required Map<String, String> displayNames,
  }) {
    if (text.isEmpty || handles.isEmpty) {
      return [MentionSpan.text(text)];
    }
    // handle → userId, for the lookup the renderer actually does.
    final byHandle = {
      for (final entry in handles.entries) entry.value: entry.key,
    };

    final spans = <MentionSpan>[];
    var cursor = 0;
    for (final match in tokenPattern.allMatches(text)) {
      final handle = match.group(1)!.toLowerCase();
      final userId = byHandle[handle];
      if (userId == null) continue;
      if (match.start > cursor) {
        spans.add(MentionSpan.text(text.substring(cursor, match.start)));
      }
      // "@You" for the reader themselves, matching the designs — being named is
      // the one thing the reader needs to spot at a glance, and their own name
      // is not how they think of it.
      final label = userId == myUserId
          ? 'You'
          : _firstWord(displayNames[userId] ?? handle);
      spans.add(MentionSpan.mention(
        '@$label',
        userId: userId,
        isMe: userId == myUserId,
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(MentionSpan.text(text.substring(cursor)));
    }
    return spans.isEmpty ? [MentionSpan.text(text)] : spans;
  }

  /// True when [text] mentions [userId] — used to decide whether a message
  /// deserves the reader's attention.
  static bool mentions(
    String text, {
    required String userId,
    required Map<String, String> handles,
  }) {
    final handle = handles[userId];
    if (handle == null) return false;
    for (final match in tokenPattern.allMatches(text)) {
      if (match.group(1)!.toLowerCase() == handle) return true;
    }
    return false;
  }

  static String _firstWord(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }
}

/// The `@…` fragment under the caret, and where it sits in the text.
class MentionQuery {
  final int start;
  final int end;
  final String query;
  const MentionQuery({
    required this.start,
    required this.end,
    required this.query,
  });
}

/// New composer text plus where the caret should end up after an insert.
class ReplacementResult {
  final String text;
  final int caret;
  const ReplacementResult({required this.text, required this.caret});
}

/// One run of a parsed message: either plain text or a resolved mention.
class MentionSpan {
  final String text;

  /// Null for plain runs.
  final String? userId;

  /// True when this mention names the reader.
  final bool isMe;

  const MentionSpan.text(this.text)
      : userId = null,
        isMe = false;

  const MentionSpan.mention(this.text, {required this.userId, this.isMe = false});

  bool get isMention => userId != null;
}
