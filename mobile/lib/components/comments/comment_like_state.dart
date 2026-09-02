import 'package:flutter/widgets.dart';

import 'package:jperg_app/features/photo_comments/data/comment_like_service.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// The heart on a comment row, for whichever sheet is drawing it.
///
/// A mixin rather than four copies. Every comment surface in the app — the
/// photo sheet, the event sheet and its web twin, the ads feed sheet — rebuilds
/// its whole list from a bloc's state on every frame, and every one of them
/// needs the same three things: an optimistic count that moves under the thumb,
/// somewhere to keep it that a rebuild will not overwrite, and a way to put it
/// back when the server does not answer.
///
/// **Why the state cannot live on the message.** The rows come from
/// `ChatRoomBloc`, which re-emits its message list whenever anything in the
/// room changes. A like written into a [ChatMessage] would be replaced the next
/// time that happened — so it is held beside the list, keyed by comment id, and
/// the message's own values are the fallback for anything not touched yet.
mixin CommentLikeState<T extends StatefulWidget> on State<T> {
  final CommentLikeService _likeService = CommentLikeService();

  /// What the server last told us, for the comments this reader has touched.
  final Map<String, ({bool liked, int likes})> _likes = {};

  /// Toggles already asking. A second tap while the first is in the air would
  /// send the state back to where it started and leave the two answers racing.
  final Set<String> _inFlight = {};

  /// The heart's state for [msg] — this session's if it has one, the server's
  /// otherwise.
  ({bool liked, int likes}) likeFor(ChatMessage msg) =>
      _likes[msg.id] ?? (liked: msg.viewerLiked, likes: msg.likeCount);

  /// What to hand [CommentRowData.onLike], or null where liking is not on
  /// offer — a comment still on its way to the server has no id to file a like
  /// against, and a heart that silently does nothing is worse than no heart.
  VoidCallback? likeHandler(ChatMessage msg) =>
      msg.isLocal ? null : () => toggleLike(msg);

  /// Optimistic: the count moves immediately and is corrected, or put back,
  /// when the server answers. A heart that waits for a round trip before it
  /// fills reads as a button that did not work.
  Future<void> toggleLike(ChatMessage msg) async {
    if (_inFlight.contains(msg.id)) return;

    final current = likeFor(msg);
    setState(() {
      _likes[msg.id] = (
        liked: !current.liked,
        likes: (current.likes + (current.liked ? -1 : 1)).clamp(0, 1 << 30),
      );
      _inFlight.add(msg.id);
    });

    final settled = await _likeService.toggle(msg.id);
    if (!mounted) return;
    setState(() {
      _inFlight.remove(msg.id);
      // Null is "the call never landed", which is not the same as "not liked":
      // the heart goes back where it was rather than showing a number nothing
      // agreed to.
      _likes[msg.id] = settled ?? current;
    });
  }
}
