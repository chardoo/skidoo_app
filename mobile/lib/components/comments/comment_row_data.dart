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
    this.onReply,
    this.onUserTap,
    this.onLongPress,
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

  final VoidCallback? onReply;

  /// Tap on avatar/name — null means not interactive (own messages, photo comments).
  final VoidCallback? onUserTap;

  /// Long-press on the comment — null means not interactive.
  final VoidCallback? onLongPress;
}
