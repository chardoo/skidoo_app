import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Its own file rather than a private class in the card, for a reason worth
/// keeping: the heart here is a *count* — how many people liked this comment —
/// and not a control with a rest state. `reaction_buttons_transparent_test`
/// audits the rail files for filled glyphs that are not the active half of a
/// conditional, which is right for a button somebody taps and wrong for a
/// label. Living outside those files keeps that guard as strict as it was.
/// The promoted comment, drawn where the caption usually is.
///
/// Two lines at most, matching the caption's own clamp — the block must not
/// change height when this swaps in, or the whole card jumps for five seconds
/// and then jumps back.
class TopCommentLine extends StatelessWidget {
  const TopCommentLine({
    super.key,
    required this.comment,
    required this.onTap,
  });

  final TopComment comment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final replies = comment.replyCount;

    return Semantics(
      button: true,
      label: 'Top comment by ${comment.authorName}. '
          '${comment.likeCount} likes. Tap to open comments.',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.favorite_rounded, size: 13.sp, color: ext.likeRed),
            SizedBox(width: 5.w),
            Text(
              '${comment.likeCount}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (replies > 0) ...[
              SizedBox(width: 8.w),
              Icon(Icons.mode_comment_outlined,
                  size: 12.sp, color: Colors.white.withValues(alpha: 0.7)),
              SizedBox(width: 4.w),
              Text(
                '$replies',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SizedBox(width: 8.w),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  if (comment.authorName.isNotEmpty)
                    TextSpan(
                      text: '${comment.authorName}  ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  TextSpan(text: comment.content),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 13.sp,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
