import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Pill that opens the Found filter sheet.
///
/// Three visual states, all from the design:
///   • resting  — neutral glass fill, no border
///   • open     — accent outline while the sheet is on screen
///   • active   — accent outline + accent label + a badge with the number of
///                filter groups in effect
class FoundFilterButton extends StatelessWidget {
  const FoundFilterButton({
    super.key,
    required this.activeCount,
    required this.onTap,
    this.isOpen = false,
  });

  final int activeCount;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final highlighted = isOpen || activeCount > 0;
    final foreground = highlighted ? ext.accentGold : ext.greetingColor;

    return Semantics(
      button: true,
      label: activeCount > 0
          ? 'Filters, $activeCount active'
          : 'Filters',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
            border: Border.all(
              color: highlighted ? ext.accentGold : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16.sp, color: foreground),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                'Filters',
                style: TextStyle(
                  color: foreground,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (activeCount > 0) ...[
                SizedBox(width: AppSpacing.sm.w),
                _Badge(count: activeCount, color: ext.accentGold),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18.r,
      height: 18.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
