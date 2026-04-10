import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/comments/comment_item_widget.dart';
import 'package:skidoo_app/components/comments/comment_row_data.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// YouTube-style threaded comment: one top-level item + expandable reply list.
///
/// Expansion state is controlled externally (passed in via [isExpanded] +
/// [onToggleReplies]) so either a BLoC or a local StatefulWidget can own it.
class ThreadedCommentWidget extends StatelessWidget {
  const ThreadedCommentWidget({
    super.key,
    required this.comment,
    required this.replies,
    required this.ext,
    required this.isExpanded,
    required this.onToggleReplies,
  });

  /// Top-level comment data (includes onReply, onUserTap, onLongPress).
  final CommentRowData comment;

  /// Replies already fetched. Empty until the user expands for the first time.
  final List<CommentRowData> replies;

  final AppThemeExtension ext;

  /// Whether replies are currently visible.
  final bool isExpanded;

  /// Called when the "X replies / Hide replies" toggle is tapped.
  final VoidCallback onToggleReplies;

  @override
  Widget build(BuildContext context) {
    // Use server count before replies are loaded; use actual count once loaded.
    final replyCount =
        replies.isNotEmpty ? replies.length : comment.replyCount;
    final hasReplies = replyCount > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top-level comment ──────────────────────────────────────────────
          CommentItemWidget(data: comment, ext: ext),

          // ── View / hide replies toggle ─────────────────────────────────────
          if (hasReplies)
            Padding(
              padding: EdgeInsets.only(left: 44.w, bottom: 6.h),
              child: GestureDetector(
                onTap: onToggleReplies,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18.w,
                      height: 1,
                      color: ext.accentGold,
                      margin: EdgeInsets.only(right: 6.w),
                    ),
                    Text(
                      isExpanded
                          ? 'Hide replies'
                          : '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                      style: TextStyle(
                        color: ext.accentGold,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16.sp,
                      color: ext.accentGold,
                    ),
                  ],
                ),
              ),
            ),

          // ── Expanded replies with gold connector ───────────────────────────
          if (isExpanded && replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 20.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 1.5,
                    margin: EdgeInsets.only(right: 10.w),
                    color: ext.accentGold.withValues(alpha: 0.25),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final reply in replies)
                          CommentItemWidget(
                            key: ValueKey(reply.id),
                            data: reply,
                            ext: ext,
                            isReply: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
