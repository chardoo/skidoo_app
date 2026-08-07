import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// A titled section header with an optional trailing action — "You may like"
/// and its ↻ on the idle screen, the tag header on the drill-down.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionIcon,
    this.onAction,
    this.actionLabel,
    this.isActionBusy = false,
  });

  final String title;
  final String? subtitle;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? actionLabel;

  /// Spins the action in place while its request is in flight.
  final bool isActionBusy;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final sub = subtitle;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.sm.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ext.greetingColor.withValues(alpha: 0.85),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    sub,
                    style: TextStyle(
                        color: ext.searchHintColor, fontSize: 12.sp),
                  ),
                ],
              ],
            ),
          ),
          if (actionIcon != null && onAction != null)
            Semantics(
              button: true,
              label: actionLabel ?? 'Refresh',
              child: GestureDetector(
                onTap: isActionBusy ? null : onAction,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xs.w),
                  child: isActionBusy
                      ? SizedBox(
                          width: 19.sp,
                          height: 19.sp,
                          child: CircularProgressIndicator(
                              color: ext.accentGold, strokeWidth: 2),
                        )
                      : Icon(actionIcon, color: ext.accentGold, size: 21.sp),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
