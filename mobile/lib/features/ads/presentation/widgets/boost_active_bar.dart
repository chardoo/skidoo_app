import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// "Boost Active — 5 of 7 days remaining", with the bar draining behind it.
///
/// Shown on a request's own details, where the person who paid can see what
/// they still have. Not on the board: a photographer reading requests has no
/// use for somebody else's countdown, and the card says "Boosted" already.
class BoostActiveBar extends StatelessWidget {
  const BoostActiveBar({
    super.key,
    required this.daysRemaining,
    required this.totalDays,
  });

  /// Days left, as the server counted them — rounded up, so a boost with hours
  /// left still reads as 1 rather than 0.
  final int daysRemaining;

  /// The length of the whole run, which is what the bar is a fraction of.
  final int totalDays;

  /// How full the bar is. Guarded because the two numbers come from different
  /// places: a total of zero would divide by zero, and a remaining greater
  /// than the total (a boost extended after this screen was built) would
  /// overflow the track.
  double get _progress {
    if (totalDays <= 0) return 0;
    return (daysRemaining / totalDays).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      label: 'Boost active, $daysRemaining of $totalDays days remaining',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Both sides are Flexible: on a narrow screen, or at a large text
          // scale, "5 of 7 days remaining" beside the label is wider than the
          // row — it overflowed by 26px at the design width before this. The
          // countdown gives way first, since the label is the shorter and more
          // important of the two.
          Row(
            children: [
              Flexible(
                child: Text(
                  'Boost Active',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Flexible(
                child: Text(
                  '$daysRemaining of $totalDays days remaining',
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 12.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6.h,
              backgroundColor: ext.searchHintColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(ext.accentGold),
            ),
          ),
        ],
      ),
    );
  }
}
