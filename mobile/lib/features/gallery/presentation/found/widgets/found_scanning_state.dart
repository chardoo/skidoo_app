import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/app_typography.dart';

/// Found's empty state for a user who *has* a face on file but no matches yet.
///
/// Distinct from the face gate on purpose: nothing is being asked of the user
/// here, so there is no primary button. The work is happening server-side and
/// the copy says so ("We'll notify you once we do") rather than implying the
/// user forgot a step.
///
/// The one action offered is the escape hatch for the case the wait doesn't
/// cover — an event whose photos aren't public yet, where the photographer
/// hands out a code.
class FoundScanningState extends StatelessWidget {
  const FoundScanningState({super.key, this.onEnterCode});

  /// Null hides the link — for hosts with no QR scanner wired up.
  final VoidCallback? onEnterCode;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl.w,
          vertical: AppSpacing.xxl.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                color: ext.cardSurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.person_search_rounded,
                size: 44.sp,
                color: ext.searchHintColor,
              ),
            ),
            SizedBox(height: AppSpacing.xxl.h),
            Text(
              'Scanning for your face',
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(color: ext.greetingColor),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              "We haven't matched you to any photo yet. We'll notify you "
              'once we do.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: ext.searchHintColor),
            ),
            if (onEnterCode != null) ...[
              SizedBox(height: AppSpacing.xxxl.h),
              _CodeLink(onTap: onEnterCode!, ext: ext),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeLink extends StatelessWidget {
  const _CodeLink({required this.onTap, required this.ext});

  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Have a code from a photographer?',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Wrap, not Row: at large OS text sizes the label outgrows one line,
        // and a Row would overflow rather than reflow.
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm.w,
          children: [
            Icon(Icons.qr_code_scanner_rounded,
                size: 18.sp, color: ext.accentGold),
            Text(
              'Have a code from a photographer?',
              style: AppTypography.captionBold.copyWith(color: ext.accentGold),
            ),
          ],
        ),
      ),
    );
  }
}
