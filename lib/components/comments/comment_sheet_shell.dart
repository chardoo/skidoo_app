import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

// Prismatic gradient colours shared between border, glow, and divider.
const _gradientColors = [
  Color(0xFFF5A623), // gold
  Color(0xFFCB5EEE), // purple
  Color(0xFF4B79F7), // blue
];

/// Shared bottom-sheet container rendered as a floating card with horizontal
/// margins, a prismatic gradient border, and a frosted-glass background.
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
      // Horizontal margins make the sheet float; bottom covers keyboard + gap.
      padding: EdgeInsets.only(
        bottom: keyboardH + 10.h,
        left: 12.w,
        right: 12.w,
      ),
      child: SizedBox(
        height: screenH * 0.72,
        child: _GradientBorderCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Container(
                  margin: EdgeInsets.only(
                    top: 14.h,
                    bottom: title != null ? 14.h : 20.h,
                  ),
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.white.withValues(alpha: 0.30),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // ── Header ──────────────────────────────────────────────────
              if (title != null) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 14.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon badge
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF5A623), Color(0xFFFF6B35)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF5A623).withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.mode_comment_rounded,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
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
                                fontSize: 16.sp,
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

                // Gradient divider line
                Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x66F5A623),
                        Color(0x44CB5EEE),
                        Colors.transparent,
                      ],
                    ),
                  ),
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

// ── Gradient border + frosted-glass card ──────────────────────────────────────

class _GradientBorderCard extends StatelessWidget {
  const _GradientBorderCard({required this.child, required this.isDark});
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const radius = 26.0;

    return Container(
      // 1.5 px prismatic border rendered as gradient container padding
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius.r),
        boxShadow: [
          // Gold glow radiating outward from top-left
          BoxShadow(
            color: const Color(0xFFF5A623).withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(-2, -2),
          ),
          // Purple glow at the bottom
          BoxShadow(
            color: const Color(0xFFCB5EEE).withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 36,
            spreadRadius: 4,
            offset: const Offset(0, 6),
          ),
          // Deep shadow for lift
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((radius - 1.5).r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 44, sigmaY: 44),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF161A2E).withValues(alpha: 0.93),
                        const Color(0xFF0C0E1C).withValues(alpha: 0.97),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.91),
                        const Color(0xFFF4F5FF).withValues(alpha: 0.88),
                      ],
              ),
              borderRadius: BorderRadius.circular((radius - 1.5).r),
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
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF5A623).withValues(alpha: isDark ? 0.18 : 0.12),
                  const Color(0xFFCB5EEE).withValues(alpha: isDark ? 0.12 : 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: const Color(0xFFF5A623).withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 28.sp,
              color: const Color(0xFFF5A623).withValues(alpha: 0.70),
            ),
          ),
          SizedBox(height: 16.h),
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
