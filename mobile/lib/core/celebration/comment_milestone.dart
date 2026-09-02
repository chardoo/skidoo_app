/// Being first, or being a round number.
///
/// A comment thread is a queue nobody can see the front of. Landing first on
/// somebody's photo, or being the hundredth person to say something, is a small
/// thing worth noticing — and it costs nothing to notice, because the server
/// already tells us where the comment landed.
///
/// **The ordinal is the server's, not ours.** `target_comment_count` is read
/// back off the row chat just updated, and it counts top-level comments only.
/// The app cannot work it out for itself: the list it holds is paginated,
/// replies do not count, and somebody else may have commented in between. A
/// number computed here would drift, and a wrong "you are the 100th" is worse
/// than no message at all.
///
/// One caveat, stated rather than hidden: the count moves down when a comment
/// is deleted, so two people can in principle both be told they were the 100th
/// — the second one after the first's comment was removed. Every product that
/// counts this way has the same property, and the alternative is a permanent
/// per-target ledger for a piece of confetti.
library;

import 'package:flutter/foundation.dart';

/// The counts worth stopping for: the first, then each power of ten from a
/// hundred up.
///
/// Deliberately sparse. A milestone on every tenth comment is a notification
/// that means nothing by the third time somebody sees it — the point is that
/// these are rare enough to feel like something.
bool isCommentMilestone(int count) {
  if (count == 1) return true;
  if (count < 100) return false;
  var n = count;
  while (n % 10 == 0) {
    n ~/= 10;
  }
  return n == 1;
}

/// "1,000" — grouped, without pulling in a formatter for one line.
@visibleForTesting
String groupDigits(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// "1st", "100th", "1,000th".
///
/// General rather than hardcoded to the milestones above: the milestones are a
/// product decision that may move, and an ordinal that only handles the ones
/// we happen to celebrate today is a trap for whoever moves them.
@visibleForTesting
String ordinal(int value) {
  final suffix = switch (value % 100) {
    11 || 12 || 13 => 'th',
    _ => switch (value % 10) {
        1 => 'st',
        2 => 'nd',
        3 => 'rd',
        _ => 'th',
      },
  };
  return '${groupDigits(value)}$suffix';
}

/// What to say to whoever just landed on [count], or null for the ordinary
/// case — which is almost every comment, and gets no interruption at all.
String? commentMilestoneMessage(int? count) {
  if (count == null || count < 1) return null;
  if (!isCommentMilestone(count)) return null;

  // Being first reads as an achievement; being the 100th reads as a place in a
  // queue. Different sentences, because they are different things.
  if (count == 1) return "You're the first to comment 🎉";
  return 'You are the ${ordinal(count)} comment 🎉';
}

/// The one-shot signal between "a comment was saved" and "something on screen
/// celebrates it".
///
/// A notifier rather than a field on two bloc states: the two comment sheets
/// are driven by different blocs and the celebration is identical in both, so
/// putting it in either state would mean writing it twice and keeping the two
/// in step. This is fired where the count arrives and consumed where the
/// overlay is mounted — see [CommentSheetShell].
class CommentMilestones {
  CommentMilestones._();

  static final CommentMilestones instance = CommentMilestones._();

  /// The message waiting to be shown, or null when there is nothing to say.
  final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  /// Called with whatever the server reported. Silent for a reply (null), for
  /// an ordinary count, and for a count that cannot be trusted.
  void report(int? count) {
    final message = commentMilestoneMessage(count);
    if (message != null) pending.value = message;
  }

  /// Shown. Cleared so a rebuild cannot celebrate the same comment twice.
  void consume() => pending.value = null;
}
