import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Shared bottom-sheet container: keyboard-avoiding, frosted-glass background,
/// rounded top, gradient drag handle, and an optional title + subtitle header.
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

    final bgColor = isDark
        ? const Color(0xFF0D0F16).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.90);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardH),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: screenH * 0.72,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              border: Border(
                top: BorderSide(
                  color: ext.accentGold.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                left: BorderSide(
                  color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.0),
                  width: 0.5,
                ),
                right: BorderSide(
                  color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.0),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag handle ───────────────────────────────────────────────
                Center(
                  child: Container(
                    margin: EdgeInsets.only(
                      top: 14.h,
                      bottom: title != null ? 14.h : 18.h,
                    ),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ext.accentGold.withValues(alpha: 0.7),
                          ext.accentGold.withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // ── Header ────────────────────────────────────────────────────
                if (title != null) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      18.w,
                      0,
                      18.w,
                      subtitle != null ? 3.h : 14.h,
                    ),
                    child: Row(
                      children: [
                        // Gold accent bar left of title
                        Container(
                          width: 3.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                ext.accentGold,
                                const Color(0xFFFF6B35),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            title!,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 17.sp,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(31.w, 0, 18.w, 14.h),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Divider(
                    height: 1,
                    color: ext.searchHintColor.withValues(alpha: 0.10),
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
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ext.accentGold.withValues(alpha: 0.10),
              border: Border.all(
                color: ext.accentGold.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 26.sp,
              color: ext.accentGold.withValues(alpha: 0.70),
            ),
          ),
          SizedBox(height: 14.h),
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
