import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// "Explore event photos →" — the way from a feed post into the event's
/// photos, and since the feed's tap now belongs to the chrome, the only way.
///
/// It appears where the automatic slide stops (the third photo) and again on
/// every third photo after that as the person swipes, plus on the last one.
/// The rhythm is the point: an offer that stood on every photo would be
/// wallpaper, and one that appeared only once would be missed by anyone who
/// swiped past it.
class ExploreEventCta extends StatelessWidget {
  const ExploreEventCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Explore event photos',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.sm.h,
          ),
          decoration: BoxDecoration(
            // Dark glass rather than the app's accent: it sits in the middle of
            // an arbitrary photo, and a coloured pill fights whatever is
            // underneath it. White on near-black reads over anything.
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Explore event photos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 16.sp),
            ],
          ),
        ),
      ),
    );
  }
}
