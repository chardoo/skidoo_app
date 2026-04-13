import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Shared bottom-sheet container: keyboard-avoiding, rounded top, drag handle,
/// and an optional title + subtitle header row (Instagram / TikTok style).
class CommentSheetShell extends StatelessWidget {
  const CommentSheetShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
  });

  final Widget child;

  /// Primary header text shown below the drag handle (e.g. "Comments").
  final String? title;

  /// Secondary header text shown below [title] in a muted style
  /// (e.g. "by Photographer Name").
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final screenH = MediaQuery.sizeOf(context).height;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardH),
      child: Container(
        height: screenH * 0.88,
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ─────────────────────────────────────────────────
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 10.h, bottom: title != null ? 10.h : 14.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            // ── Header title + subtitle ──────────────────────────────────────
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, subtitle != null ? 2.h : 10.h),
                child: Text(
                  title!,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 12.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Divider(height: 1, color: ext.searchHintColor.withValues(alpha: 0.15)),
            ],

            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Empty state shown when there are no comments yet.
class CommentEmptyState extends StatelessWidget {
  const CommentEmptyState({super.key, required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 36.sp, color: ext.searchHintColor),
          SizedBox(height: 8.h),
          Text(
            'No comments yet.\nBe the first!',
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
