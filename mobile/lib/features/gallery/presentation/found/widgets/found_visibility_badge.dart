import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// "Public" / "Private" pill shown over the top-left of a photo in the Found
/// viewer — a dot in the state colour plus the label, on a dark scrim so it
/// stays legible over any image.
///
/// The design gives each state its own colour and tints **both** the dot and
/// the label with it: public is amber (#FAC775), private is the accent green
/// (#1D9E75). Two things were wrong here before — the pair was inverted
/// (green meant public, grey meant private) and the label was always white,
/// which left the dot carrying the whole distinction at 6px across.
class FoundVisibilityBadge extends StatelessWidget {
  const FoundVisibilityBadge({super.key, required this.isPublic});

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final stateColor = isPublic ? ext.publicAmber : ext.accentGold;

    return Semantics(
      label: isPublic ? 'Public photo' : 'Private photo',
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.r,
              height: 6.r,
              decoration:
                  BoxDecoration(color: stateColor, shape: BoxShape.circle),
            ),
            SizedBox(width: AppSpacing.sm.w),
            Text(
              isPublic ? 'Public' : 'Private',
              style: TextStyle(
                color: stateColor,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
