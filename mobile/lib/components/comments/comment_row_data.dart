import 'package:flutter/material.dart';

/// Model-agnostic display data for a single comment/reply row.
/// Both [ChatMessage] and [PhotoComment] are mapped to this before
/// being passed to the shared comment widgets.
class CommentRowData {
  const CommentRowData({
    required this.id,
    required this.label,
    required this.content,
    required this.timeLabel,
    required this.isMe,
    this.isPending = false,
    this.replyCount = 0,
    this.likeCount = 0,
    this.viewerLiked = false,
    this.onLike,
    this.onReply,
    this.onUserTap,
    this.onLongPress,
    this.canEdit = false,
    this.canDelete = false,
  });

  final String id;
  final String label;
  final String content;
  final String timeLabel;
  final bool isMe;

  /// True for optimistically posted messages not yet confirmed by server.
  final bool isPending;

  /// Server-reported reply count (shown before replies are fetched).
  final int replyCount;

  /// The heart beside Reply, and whether this reader is one of them.
  ///
  /// The count is the comment's own; `viewerLiked` is a fact about the pair and
  /// is filled in per request. Both default to the quiet state, so a surface
  /// that has not wired likes up yet draws an unlit heart at zero rather than
  /// nothing at all.
  final int likeCount;
  final bool viewerLiked;

  /// Null where liking is not offered — the heart is then not drawn at all,
  /// rather than drawn dead.
  final VoidCallback? onLike;

  final VoidCallback? onReply;

  /// Tap on avatar/name — null means not interactive (own messages, photo comments).
  final VoidCallback? onUserTap;

  /// Long-press on the comment — null means not interactive.
  final VoidCallback? onLongPress;

  /// Whether this reader may change what the comment says.
  ///
  /// The author, and nobody else. The creator of the album may take a comment
  /// down but may not rewrite it — removing somebody's words and putting
  /// different ones in their mouth are not the same act, and only one of them
  /// is moderation. Enforced on the server either way; this decides whether
  /// the option is offered at all.
  final bool canEdit;

  /// Whether this reader may remove the comment.
  ///
  /// The author, or the creator of the content it is sitting on.
  final bool canDelete;
}
