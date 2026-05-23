import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Shared text-input bar for both event and photo comments.
///
/// Accepts [replyingToName] as a plain string (no model dependency).
/// When non-null, a gold reply banner is shown above the text field.
class CommentInputBarWidget extends StatelessWidget {
  const CommentInputBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.ext,
    this.replyingToName,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final AppThemeExtension ext;

  /// Display name of the user being replied to. Null means no active reply.
  final String? replyingToName;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Reply banner ─────────────────────────────────────────────────────
        if (replyingToName != null)
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 8.w, 8.h),
            decoration: BoxDecoration(
              color: ext.accentGold.withValues(alpha: 0.08),
              border: Border(
                top: BorderSide(
                    color: ext.accentGold.withValues(alpha: 0.25), width: 1),
                left: BorderSide(color: ext.accentGold, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.reply_rounded, size: 14.sp, color: ext.accentGold),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Replying to $replyingToName',
                    style: TextStyle(
                      color: ext.accentGold,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4.w),
                GestureDetector(
                  onTap: onCancelReply,
                  child: Icon(Icons.close_rounded,
                      size: 16.sp, color: ext.searchHintColor),
                ),
              ],
            ),
          ),

        // ── Text input ───────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            border: Border(
              top: BorderSide(
                  color: ext.searchHintColor.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: replyingToName != null
                        ? 'Write a reply…'
                        : 'Add a comment…',
                    hintStyle: TextStyle(
                        color: ext.searchHintColor, fontSize: 14.sp),
                    filled: true,
                    fillColor: ext.searchFieldFill,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(22.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 10.h),
                    isDense: true,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                      color: ext.accentGold, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(Icons.send_rounded,
                      color: Colors.white, size: 20.sp),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
