import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The short bar at the top of a bottom sheet that says "drag me".
///
/// Two sheets had declared byte-identical private copies of this, and half a
/// dozen more built the same rounded bar inline at their own width. It is the
/// same affordance every time, so it is one widget.
class AppDragHandle extends StatelessWidget {
  const AppDragHandle({super.key, this.color});

  /// Defaults to the theme's hint colour at half strength — present enough to
  /// invite the drag, quiet enough not to compete with the sheet's content.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final base = color ?? ext?.searchHintColor ?? Colors.grey;

    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.md.h),
      child: Center(
        child: Container(
          width: 36.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
          ),
        ),
      ),
    );
  }
}
