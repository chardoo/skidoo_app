import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// An in-page message that stays put until it is answered.
///
/// The auth screens used to report failures with a floating SnackBar. A
/// SnackBar is the wrong instrument for "we could not sign you in": it appears
/// at the *bottom* of the screen, three seconds after you tapped a button at
/// the top of it, and then removes itself — so the one piece of text that
/// explains what to fix is gone before a keyboard-covered form has scrolled
/// back into view, and there is nothing to re-read afterwards. Worse, on the
/// sign-up screen it lands under the on-screen keyboard entirely.
///
/// This sits in the form, above the fields it is talking about, and stays
/// until the user acts on it or dismisses it — and it can carry an action, so
/// "you already have an account" can offer the *Log in* button that resolves
/// it rather than only naming the problem.
enum AppBannerKind { error, info, success }

class AppInlineBanner extends StatelessWidget {
  const AppInlineBanner({
    super.key,
    required this.message,
    this.kind = AppBannerKind.error,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppBannerKind kind;

  /// Shows the close affordance. Omit for a banner the user should resolve by
  /// fixing the field rather than by hiding the message.
  final VoidCallback? onDismiss;

  /// An inline way out of the situation the banner describes — "Log in",
  /// "Verify now". Both must be supplied for the button to appear.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final (Color accent, IconData icon) = switch (kind) {
      AppBannerKind.error => (ext.errorRed, Icons.error_outline_rounded),
      AppBannerKind.info => (ext.infoBlue, Icons.info_outline_rounded),
      AppBannerKind.success => (ext.accentGold, Icons.check_circle_outline_rounded),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md.w,
          AppSpacing.md.h,
          AppSpacing.sm.w,
          AppSpacing.md.h,
        ),
        decoration: BoxDecoration(
          // A tint of the accent rather than the full colour: this sits inside
          // a form, not on top of it, and a solid red block reads as a failed
          // screen rather than a field that needs another look.
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 18.sp),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 13.sp,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    SizedBox(height: AppSpacing.xs.h),
                    Semantics(
                      button: true,
                      label: actionLabel,
                      child: GestureDetector(
                        onTap: onAction,
                        child: Padding(
                          // Taps land on a 44-high strip, not on the glyph
                          // height of the text.
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
                          child: Text(
                            actionLabel!,
                            style: TextStyle(
                              color: accent,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              Semantics(
                button: true,
                label: 'Dismiss',
                child: GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xs.w),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16.sp,
                      color: ext.searchHintColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
