import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Shared bottom-sheet container: frosted-glass background, rounded top,
/// gradient drag handle, and an optional title + subtitle header row.
class CommentSheetShell extends StatelessWidget {
  const CommentSheetShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.sizeOf(context).height;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    // Frosted-glass tint — noticeably transparent so the blur shows through
    final bgColor = isDark
        ? const Color(0xFF0B0D14).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.82);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardH),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: Container(
            height: screenH * 0.74,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24.r)),
              // Thin top border that catches the light
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.60),
                  width: 1.0,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag handle ───────────────────────────────────────────
                Center(
                  child: Container(
                    margin: EdgeInsets.only(
                      top: 12.h,
                      bottom: title != null ? 10.h : 16.h,
                    ),
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // ── Header ────────────────────────────────────────────────
                if (title != null) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20.w,
                      0,
                      20.w,
                      subtitle != null ? 2.h : 10.h,
                    ),
                    child: Text(
                      title!,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.sp,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
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
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                ],

                Expanded(child: child),
              ],
            ),
          ),
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
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 38.sp,
            color: ext.searchHintColor.withValues(alpha: 0.5),
          ),
          SizedBox(height: 12.h),
          Text(
            'No comments yet',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Be the first to say something',
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }
}
