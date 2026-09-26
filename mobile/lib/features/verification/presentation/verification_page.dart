import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/verification/data/verification_api.dart';
import 'package:jperg_app/features/verification/presentation/verification_form.dart';

/// Account & Security → Verification.
///
/// The same form the creator wizard ends on, reachable on its own — because a
/// submission can be rejected, and somebody who was rejected needs somewhere
/// to go that is not "sign up as a creator again". It is also where a creator
/// who skipped the step during onboarding picks it back up.
///
/// Creators only. A client has nothing to verify: the badge is about somebody
/// being paid for work, and a screen offering it to everybody would be a
/// screen most people cannot act on.
class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key, this.api});

  final VerificationApi? api;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: Text(
          'Verification',
          style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h,
            AppSpacing.lg.w, AppSpacing.xxxl.h),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm who you are',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontFamily: AppTypography.displayFontFamily,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  'Verified creators are easier to trust, and it is what we '
                  'check against before a payout.',
                  style:
                      TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                ),
                SizedBox(height: AppSpacing.lg.h),
                VerificationForm(api: api),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
