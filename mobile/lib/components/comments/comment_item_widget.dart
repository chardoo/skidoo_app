import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/comments/comment_row_data.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// Single comment/reply row — model-agnostic.
/// Accepts pre-computed [CommentRowData]; contains no BLoC or model imports.
class CommentItemWidget extends StatelessWidget {
  const CommentItemWidget({
    super.key,
    required this.data,
    required this.ext,
    this.isReply = false,
  });

  final CommentRowData data;
  final AppThemeExtension ext;

  /// True when rendered as an indented reply (smaller avatar, tighter spacing).
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final avatarColor = data.isMe ? ext.accentGold : Colors.blueAccent;
    // Instagram: 32dp top-level / 24dp replies. We match with screenutil.
    final avatarSize = isReply ? 28.w : 36.w;
    final canChat = data.onUserTap != null;

    return GestureDetector(
      onLongPress: data.onLongPress,
      child: Padding(
        padding: EdgeInsets.only(bottom: isReply ? 4.h : 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar ────────────────────────────────────────────────────────
            Semantics(
                button: true,
                label: 'View profile',
                child: GestureDetector(
                  onTap: canChat ? data.onUserTap : null,
                  child: Stack(
                    children: [
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          color: avatarColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: canChat
                              ? Border.all(
                                  color: ext.accentGold.withValues(alpha: 0.45),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          data.label.isNotEmpty
                              ? data.label[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: avatarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: isReply ? 11.sp : 13.sp,
                          ),
                        ),
                      ),
                      // DM badge — only when tappable
                      if (canChat)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12.w,
                            height: 12.w,
                            decoration: BoxDecoration(
                              color: ext.accentGold,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: ext.homeBackground, width: 1.5),
                            ),
                            child: Icon(Icons.chat_bubble_rounded,
                                size: 6.sp, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                )),
            SizedBox(width: 10.w),

            // ── Message body ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time
                  Row(
                    children: [
                      Semantics(
                          button: true,
                          label: 'View profile',
                          child: GestureDetector(
                            onTap: canChat ? data.onUserTap : null,
                            child: Text(
                              data.label,
                              style: TextStyle(
                                color: canChat
                                    ? ext.accentGold
                                    : (data.isMe
                                        ? ext.accentGold
                                        : ext.greetingColor),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.sp,
                                decoration: canChat
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                                decorationColor:
                                    ext.accentGold.withValues(alpha: 0.5),
                              ),
                            ),
                          )),
                      SizedBox(width: 6.w),
                      Text(
                        data.timeLabel,
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 11.sp),
                      ),
                      if (data.isPending) ...[
                        SizedBox(width: AppSpacing.xs.w),
                        Icon(Icons.access_time_rounded,
                            size: 10.sp, color: ext.searchHintColor),
                      ],
                    ],
                  ),
                  SizedBox(height: 1.h),

                  // Content
                  Text(
                    data.content,
                    style: TextStyle(
                        color: ext.greetingColor, fontSize: 13.sp, height: 1.3),
                  ),

                  // Reply button
                  if (data.onReply != null)
                    Semantics(
                        button: true,
                        label: 'Reply',
                        child: GestureDetector(
                          onTap: data.onReply,
                          child: Padding(
                            padding: EdgeInsets.only(top: 3.h),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                color: ext.searchHintColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
