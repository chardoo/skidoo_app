import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_access.dart';

/// What a signed-out visitor sees on the Found tab.
///
/// The only thing worth offering them. Found lists photos recognised as *you*,
/// and both routes to that need an account: the stored listing is per-account,
/// and easy search reads who you are from the token. Offering a code sheet
/// here would invite somebody to scan something the server would then refuse
/// to search.
///
/// This replaced the old "Add your face to get found" panel, which asked a
/// guest for a selfie before it had asked them for an account — putting the
/// second step first, and making face capture look like the price of entry
/// when the actual price is signing up.
class FoundJoinPrompt extends StatelessWidget {
  const FoundJoinPrompt({
    super.key,
    required this.onJoin,
    required this.onSignIn,
  });

  final VoidCallback onJoin;
  final VoidCallback onSignIn;

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
              width: 84.w,
              height: 84.w,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 38.sp,
                color: ext.accentGold,
              ),
            ),
            SizedBox(height: AppSpacing.xxl.h),
            Text(
              kJoinPromptHeadline,
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(color: ext.greetingColor),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              'Photos of you from events you attend land here, once you have '
              'an account to put them in.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: ext.searchHintColor),
            ),
            SizedBox(height: AppSpacing.xxxl.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill.r),
                  ),
                ),
                child: Text(
                  'Create an account',
                  style: AppTypography.bodyBold.copyWith(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md.h),
            TextButton(
              onPressed: onSignIn,
              child: Text(
                'Already have an account? Sign in',
                style: AppTypography.caption.copyWith(color: ext.accentGold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
