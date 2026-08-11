import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// "3 of 16" over the top-left of the photo.
///
/// Where the counter goes once the app bar is showing the album's name
/// instead. Same dark scrim as [FoundVisibilityBadge], because it sits in the
/// same corner over the same unpredictable photo and the two should not read
/// as different kinds of thing.
class FoundCounterPill extends StatelessWidget {
  const FoundCounterPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.xs.h,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              // Tabular so the pill does not resize as the index ticks past 9,
              // which reads as a jitter when swiping quickly.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
