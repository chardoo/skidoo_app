import 'package:flutter/widgets.dart';

import 'session_cache.dart';

/// The comment count for anything currently on screen, once it stops matching
/// what the feed said.
///
/// A card's count arrives inside immutable feed data and nothing rewrites it,
/// so posting a comment left the badge showing the number it had when the list
/// was fetched. The comment sheet updated its own list and closed, and the card
/// behind it still read one fewer — until something forced a refetch, which for
/// a cached feed could be a long time.
///
/// This is deliberately *not* a [CacheSignal]. Those say "what you hold is
/// stale, ask again", which is right for a list that has to be rebuilt and
/// wrong for a single number: refetching a whole feed to move one badge by one
/// is a lot of work to watch a "3" become a "4". This holds the number itself.
///
/// The values are **authoritative, not arithmetic** — they come from
/// `target_comment_count` on the create response, which chat reads back out of
/// the row it just updated. The app cannot work the total out for itself:
/// replies do not count towards it, the list it holds is paginated, and
/// somebody else may have commented since it loaded. Anything computed here
/// would be a guess that drifts further with every use.
///
/// Keyed by target id, so the same item updates in every list it appears in at
/// once — a photo in a feed, in an album and in saved items are three cards
/// showing one thing.
class CommentCounts extends ChangeNotifier {
  CommentCounts._() {
    // Per-account, like everything else here: one signed-in user must never be
    // shown another's leftovers.
    SessionCache.register(clear);
  }

  static final CommentCounts instance = CommentCounts._();

  final Map<String, int> _counts = {};

  /// The live count for [targetId], or null if nothing has changed it since the
  /// screen loaded. Null means "use whatever you were given" — it is not zero.
  int? countFor(String? targetId) {
    if (targetId == null || targetId.isEmpty) return null;
    return _counts[targetId];
  }

  /// Record the count the server reported after a change.
  ///
  /// Ignores null, which is what chat sends when the count did not move — a
  /// reply — or when it could not be read back. Overwriting a good number with
  /// a guess in either case would be worse than showing a slightly old one.
  void report(String? targetId, int? count) {
    if (targetId == null || targetId.isEmpty || count == null) return;
    if (count < 0) return;
    if (_counts[targetId] == count) return;
    _counts[targetId] = count;
    notifyListeners();
  }

  /// Nudge a count we have no authoritative value for.
  ///
  /// Only for deletion: that endpoint answers 204 with no body, so there is no
  /// number to read back. The result is corrected by the next [report], and
  /// clamped at zero because a badge must never render a negative.
  void adjust(String? targetId, int delta, {required int base}) {
    if (targetId == null || targetId.isEmpty || delta == 0) return;
    final current = _counts[targetId] ?? base;
    final next = current + delta;
    _counts[targetId] = next < 0 ? 0 : next;
    notifyListeners();
  }

  void clear() {
    if (_counts.isEmpty) return;
    _counts.clear();
    notifyListeners();
  }
}

/// Rebuilds [builder] with the live comment count for [targetId].
///
/// Falls back to [fallback] — the count the card was built with — until
/// something reports a newer one, so a card that nobody has commented on costs
/// nothing but a listener.
class LiveCommentCount extends StatelessWidget {
  const LiveCommentCount({
    super.key,
    required this.targetId,
    required this.fallback,
    required this.builder,
  });

  final String? targetId;
  final int fallback;
  final Widget Function(BuildContext context, int count) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CommentCounts.instance,
      builder: (context, _) => builder(
        context,
        CommentCounts.instance.countFor(targetId) ?? fallback,
      ),
    );
  }
}
