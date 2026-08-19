import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Shared bottom-sheet container for every comment surface — the photo sheet,
/// the event sheet, the ads feed sheet.
///
/// Presented like [ShareTargetSheet] and the Hide/Report sheet: flush to the
/// screen edges, rounded across the top two corners only, on the app's own
/// surface colour. It used to be a floating frosted card — inset from both
/// edges, rounded on all four corners, a 52-pixel backdrop blur behind a
/// half-transparent fill, a hairline border and a 28-pixel drop shadow. That
/// is a lot of chrome for a list of comments, and it made this the only sheet
/// in the app that looked like a different app.
///
/// The height is deliberate and shared: see [kCommentSheetFraction], which
/// [CommentPushArea] reads to work out how far to scale the page above it.
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
      // Bottom only. The left/right inset was what made this a floating card
      // rather than a sheet.
      padding: EdgeInsets.only(bottom: keyboardH),
      child: SizedBox(
        height: screenH * kCommentSheetFraction,
        child: _SheetSurface(
          ext: ext,
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
                                color:
                                    isDark ? Colors.white : ext.greetingColor,
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

// ── Sheet surface ─────────────────────────────────────────────────────────────

/// The same surface [ShareTargetSheet] and the Hide/Report sheet sit on: the
/// app background, rounded across the top, flush everywhere else.
///
/// Opaque on purpose. The page behind is no longer dimmed — it scales up into
/// the strip above (see [CommentPushArea]) — so anything translucent here
/// would show the photo through the comments.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child, required this.ext});
  final Widget child;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(20.r));

    return Container(
      decoration: BoxDecoration(color: ext.homeBackground, borderRadius: radius),
      child: ClipRRect(borderRadius: radius, child: child),
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
