import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Shared bottom-sheet container: floating frosted-glass card with a thin
/// neutral border and a single lift shadow.
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

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: keyboardH + 10.h,
        left: 12.w,
        right: 12.w,
      ),
      child: SizedBox(
        height: screenH * 0.72,
        child: _FrostedCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  margin: EdgeInsets.only(
                    top: 14.h,
                    bottom: title != null ? 14.h : 20.h,
                  ),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // ── Header ───────────────────────────────────────────────────
              if (title != null) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 14.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mode_comment_outlined,
                        color: ext.searchHintColor,
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title!,
                              style: TextStyle(
                                color: isDark ? Colors.white : ext.greetingColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 15.sp,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null) ...[
                              SizedBox(height: 1.h),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: ext.searchHintColor,
                                  fontSize: 11.sp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.10),
                ),
              ],

              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Frosted-glass card ────────────────────────────────────────────────────────

class _FrostedCard extends StatelessWidget {
  const _FrostedCard({required this.child, required this.isDark});
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const radius = 26.0;
    final borderColor = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: isDark ? 0.14 : 0.08);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius.r),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.52)
                  : Colors.white.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(radius.r),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class CommentEmptyState extends StatelessWidget {
  const CommentEmptyState({super.key, required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 26.sp,
              color: ext.searchHintColor,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'No comments yet',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 5.h),
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
